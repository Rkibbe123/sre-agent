# ==============================
# Azure SRE Agent (Preview) - Create/Update
# ==============================

# ----- Inputs (ALL CAPS as you prefer) -----
$SUBSCRIPTION_ID   = "d5736eb1-f851-4ec3-a2c5-ac8d84d029e2"
$RESOURCE_GROUP    = "rg-rkibbe-2470"
$LOCATION          = "eastus2"
$AGENT_NAME        = "rkibbe"
$UAMI_NAME         = "$AGENT_NAME-uami"

# Optional (leave empty to skip Application Insights wiring)
$APPINSIGHTS_RESOURCE_ID = ""

# Target scopes the agent should analyze (ARM IDs)
$MANAGED_RESOURCES = @(
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-rkibbe-2470"
)

$API_VERSION = "2025-05-01-preview"

Write-Host "SUBSCRIPTION_ID : [$SUBSCRIPTION_ID]"
Write-Host "RESOURCE_GROUP  : [$RESOURCE_GROUP]"
Write-Host "LOCATION        : [$LOCATION]"
Write-Host "AGENT_NAME      : [$AGENT_NAME]"
Write-Host "UAMI_NAME       : [$UAMI_NAME]"

# 1) Subscription
az account set --subscription $SUBSCRIPTION_ID | Out-Null

# 2) Provider registration (Preview requirement)
az provider register --namespace Microsoft.App | Out-Null
Write-Host "Waiting for Microsoft.App provider to be Registered..." -ForegroundColor Cyan
for ($i=0; $i -lt 30; $i++) {
  $state = az provider show -n Microsoft.App --query registrationState -o tsv 2>$null
  if ($state -eq "Registered") { break }
  Start-Sleep -Seconds 5
}
if ($state -ne "Registered") { throw "Provider 'Microsoft.App' not Registered yet. Try again shortly." }

# Optional: ensure preview API version is visible
$apiVisible = az provider show -n Microsoft.App --query "resourceTypes[?resourceType=='agents'].apiVersions[]" -o tsv |
  Select-String $API_VERSION -Quiet
if (-not $apiVisible) { throw "Preview API $API_VERSION for Microsoft.App/agents not visible yet; retry in a few minutes." }

# 3) Create or get UAMI
$UAMI_ID = az identity show -g $RESOURCE_GROUP -n $UAMI_NAME --query id -o tsv 2>$null
if (-not $UAMI_ID) {
  Write-Host "Creating UAMI: $UAMI_NAME in $RESOURCE_GROUP ($LOCATION)..." -ForegroundColor Cyan
  $UAMI_ID = az identity create -g $RESOURCE_GROUP -n $UAMI_NAME -l $LOCATION --query id -o tsv
}
# Retry fetch principalId (handles transient 10054 connection reset)
$UAMI_PRINCIPAL_ID = $null
for ($r=0; $r -lt 5 -and [string]::IsNullOrWhiteSpace($UAMI_PRINCIPAL_ID); $r++) {
  Start-Sleep -Seconds 2
  $UAMI_PRINCIPAL_ID = az identity show -g $RESOURCE_GROUP -n $UAMI_NAME --query principalId -o tsv 2>$null
}
Write-Host "UAMI ID        : $UAMI_ID"
Write-Host "UAMI Principal : $UAMI_PRINCIPAL_ID"

# 4) (Optional) Assign Reader on your managed scopes
# foreach ($scope in $MANAGED_RESOURCES) {
#   az role assignment create --assignee-object-id $UAMI_PRINCIPAL_ID --assignee-principal-type ServicePrincipal --role "Reader" --scope $scope | Out-Null
# }

# 5) Build the payload object
$properties = [ordered]@{
  actionConfiguration = @{
    accessLevel = "High"
    mode        = "review"  # change to "autonomous" later if desired
    identity    = $UAMI_ID
  }
  incidentManagementConfiguration = @{
    type = "AzMonitor"
  }
  knowledgeGraphConfiguration = @{
    identity         = $UAMI_ID
    managedResources = $MANAGED_RESOURCES
  }
  upgradeChannel = "Stable"
}

# Only include logConfiguration when App Insights is actually set
if (-not [string]::IsNullOrWhiteSpace($APPINSIGHTS_RESOURCE_ID)) {
  $properties.logConfiguration = @{
    applicationInsightsConfiguration = @{
      applicationInsightsResourceId = $APPINSIGHTS_RESOURCE_ID
    }
  }
}

$payload = [ordered]@{
  location = $LOCATION
  identity = @{
    type = "SystemAssigned,UserAssigned"
    userAssignedIdentities = @{ $UAMI_ID = @{} }
  }
  properties = $properties
}

# Convert to JSON and persist to file (UTF-8 no BOM)
$payloadJson = $payload | ConvertTo-Json -Depth 20
$payloadPath = Join-Path $PSScriptRoot "agent.json"
[System.IO.File]::WriteAllText($payloadPath, $payloadJson, [System.Text.UTF8Encoding]::new($false))
Write-Host "Payload written to: $payloadPath" -ForegroundColor Cyan
Write-Host $payloadJson

# 6) Create/Update via az rest - retry loop for transient 10054 errors
$AGENT_URI = "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.App/agents/${AGENT_NAME}?api-version=${API_VERSION}"
Write-Host "AGENT_URI: $AGENT_URI" -ForegroundColor Yellow

$MAX_RETRIES = 5
$putSuccess  = $false
for ($attempt = 1; $attempt -le $MAX_RETRIES; $attempt++) {
  Write-Host "PUT attempt $attempt of $MAX_RETRIES ..." -ForegroundColor Cyan
  $result = az rest `
    --method put `
    --uri $AGENT_URI `
    --headers "Content-Type=application/json" `
    --body "@$payloadPath" 2>&1

  if ($LASTEXITCODE -eq 0) {
    Write-Host "PUT succeeded." -ForegroundColor Green
    $result | Write-Host
    $putSuccess = $true
    break
  }

  $errText = $result -join "`n"
  # Retry on transient connection resets (10054) or throttle (429)
  if ($errText -match '10054|ConnectionResetError|Connection aborted|Retry|throttled') {
    $delay = [math]::Pow(2, $attempt) * 5   # 10s, 20s, 40s, 80s, 160s
    Write-Host "Transient error detected. Retrying in ${delay}s..." -ForegroundColor Yellow
    Write-Host $errText -ForegroundColor DarkGray
    Start-Sleep -Seconds $delay
  } else {
    Write-Host "Non-retryable error:" -ForegroundColor Red
    Write-Host $errText
    break
  }
}

if (-not $putSuccess) {
  Write-Host "Failed to create/update agent after $MAX_RETRIES attempts." -ForegroundColor Red
  exit 1
}

# 7) Verify (with retry for propagation delay)
Write-Host "Waiting 10s for ARM propagation..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

for ($v = 1; $v -le 3; $v++) {
  $verify = az resource show `
    --resource-group "$RESOURCE_GROUP" `
    --resource-type "Microsoft.App/agents" `
    --name "$AGENT_NAME" `
    --query "{provisioningState:properties.provisioningState, runningState:properties.runningState, endpoint:properties.agentEndpoint}" `
    -o table 2>&1
  if ($LASTEXITCODE -eq 0) { $verify; break }
  Write-Host "Verify attempt $v failed, retrying in 10s..." -ForegroundColor Yellow
  Start-Sleep -Seconds 10
}