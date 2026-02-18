# Building Semi-Autonomous Intelligent Pipelines

## Azure AI Agents, SRE Agents, and MCP Servers in CI/CD

*A Practical Guide to Self-Healing Deployment Pipelines*

---

**Author:** Randy Kibbe
**Date:** February 2026
**Platform:** Azure DevOps, Azure AI Foundry, Azure SRE Agent (Preview)

---

## Table of Contents

- [Foreword: The Death of DevOps & the Rise of AI-Ops](#foreword)
1. [Introduction: The Problem with Traditional Pipelines](#chapter-1-introduction)
2. [Architecture Overview: Two Agents, One Pipeline](#chapter-2-architecture-overview)
3. [The AI Agent: Code Intelligence at Build Time](#chapter-3-the-ai-agent)
4. [The Azure SRE Agent: Infrastructure Intelligence at Deploy Time](#chapter-4-the-azure-sre-agent)
5. [MCP Servers: The Connective Tissue](#chapter-5-mcp-servers)
6. [Pipeline Design: Composable Template Architecture](#chapter-6-pipeline-design)
7. [Pre-Deployment: Readiness Gates and Baseline Capture](#chapter-7-pre-deployment)
8. [Post-Deployment: Validation, Rollback, and Incident Response](#chapter-8-post-deployment)
9. [Observability: Health Reports, Baselines, and Reliability Audits](#chapter-9-observability)
10. [Making It Semi-Autonomous: The Trust Spectrum](#chapter-10-semi-autonomous)
11. [Lessons Learned and What's Next](#chapter-11-lessons-learned)

---

## Foreword: The Death of DevOps & the Rise of AI‑Ops

*Adapted from ["The Death of DevOps & the Rise of AI‑Ops"](https://medium.com/@rkibbe1/the-death-of-devops-the-rise-of-ai-ops-b35aa20dfd42) by Randy Kibbe*

If you are a DevOps Engineer still performing the same tasks you have for the last year or longer — you're about to be on the next episode of *The Walking Dead*.

You're not going to be writing PowerShell or Bash scripts forever. The days of authoring YAML files, babysitting CI/CD pipelines, and manually gluing services together are coming to an abrupt end. And while many engineers believe they're "on the AI wave" because they use GitHub Copilot for autocomplete in VS Code, that's barely scratching the surface. The newest wave of AI agents isn't just helping you code — they're becoming fully context‑aware participants in your environment. The next generation of agents won't simply assist you; they'll replace large portions of what you do today.

But this isn't a doom story — it's a pivot story.

There is a viable, meaningful future for people who embrace AI instead of ignoring it. Imagine a future where you're not authoring brittle scripts, triaging noisy alerts, refreshing dashboards, or jumping onto a Sev‑1 call in the middle of dinner. That future is **AI‑Ops**.

### What is AI‑Ops?

AI‑Ops isn't just "DevOps with AI sprinkled on top." It's a fundamental rethinking of what operational excellence looks like when execution speed, context‑awareness, and real‑time decision‑making are no longer bottlenecked by humans.

AI‑Ops is the integration of autonomous and semi‑autonomous agents directly into your operational fabric. These agents don't just observe — they act. They monitor your systems 24/7, correlate telemetry across services, detect anomalies in milliseconds, and in many cases, take the first (or full) remediation steps on your behalf. While DevOps required humans to orchestrate tools, AI‑Ops flips that model: **humans orchestrate intent, and AI orchestrates everything else**.

Your pipelines, infrastructure, security posture, performance optimizations, and incident response workflows become living systems that adapt to your environment in real time.

### Where AI Agents Fit Today

You don't need to wait for some far‑off future to start using these agents. You can embed AI directly into your pipelines today — GitHub Actions, Azure DevOps, GitLab, wherever you ship code. Tools like **Azure SRE Agent** already integrate at every lifecycle touchpoint, acting as a readiness gate before deployment, validating health after deployment, scanning logs, detecting anomalies, and even triggering automated rollback the moment something looks off.

You don't need to rewrite your entire CI/CD architecture. You simply add an AI step that evaluates the environment, analyzes the artifacts, and decides whether to continue, pause, roll back, or alert:

```yaml
- name: AI Pre‑Deploy Gate
  run: |
    curl -X POST $SRE_AGENT_ENDPOINT \
      -H "Authorization: Bearer $TOKEN" \
      -d '{ "action": "readiness-check", "env": "dev" }'
```

That single block of automation replaces hours of manual checklisting and guesswork. The moment you wire an AI agent into CI/CD, your pipeline stops being a dumb conveyor belt and becomes an intelligent system — one that predicts failures, prevents bad releases, and shortens your operational feedback loop from hours to seconds.

### The Shift

Your value as an engineer shifts from *doing the work* to *designing the systems that do the work*. The engineers who thrive in the coming decade won't be those writing the most scripts — they'll be the ones training, guiding, and curating the behaviors of AI agents. They'll design automated policies, evaluate agent recommendations, architect resilient systems that leverage autonomous remediation, and focus on business outcomes instead of mechanical tasks.

This book is a practical guide to making that shift. It documents a working implementation — a real pipeline running in production — that embeds two AI agents into every phase of the deployment lifecycle. It's not theory. It's the blueprint.

---

## Chapter 1: Introduction

### The Problem with Traditional Pipelines

The foreword described the macro shift from DevOps to AI‑Ops. This chapter gets specific: what exactly breaks in traditional pipelines, and how do intelligent agents fix it?

CI/CD pipelines have traditionally been deterministic scripts: run tests, build artifacts, deploy, done. When something fails, a human reads the logs, diagnoses the issue, and either fixes it or rolls back. This model breaks down at scale for three reasons:

1. **Log volume**: A typical Azure DevOps pipeline generates thousands of lines of output. The signal-to-noise ratio is terrible. Engineers waste hours searching for the one line that matters.

2. **Post-deploy blind spots**: Most pipelines stop caring the moment deployment finishes. They don't check whether the thing they just deployed is actually working. By the time someone notices a problem, users have already been affected.

3. **Tribal knowledge**: Knowing *what to look for* in a deployment — which metrics matter, what "normal" looks like, when to roll back — lives in people's heads. When those people aren't available, deployments stall or fail silently.

This guide describes a working implementation that addresses all three problems by embedding two AI-powered agents directly into the pipeline lifecycle:

- An **AI Agent** (Azure OpenAI) that reads code, scans for vulnerabilities, reviews logs, and provides expert-level analysis — at build time.
- An **Azure SRE Agent** (Preview) that monitors infrastructure health, gates deployments, detects anomalies, triggers rollbacks, and files incidents — at deploy time.

Together, they create a pipeline that can reason about what it's deploying, decide whether the environment is ready, validate that the deployment succeeded, and take corrective action when it doesn't — with minimal human intervention.

---

## Chapter 2: Architecture Overview

### Two Agents, One Pipeline

The pipeline is structured as an 11-stage Azure DevOps YAML pipeline. The stages form a linear dependency chain with conditional branches for failure handling:

```
┌─────────────────────┐
│  1. AI Code Review  │  ← AI Agent: code quality, security, best practices
│     & Security Scan │
└────────┬────────────┘
         │
┌────────▼────────────┐
│  2. SRE Pre-Deploy  │  ← SRE Agent: environment readiness, alert check,
│     Readiness Gate  │     baseline capture, GO/NO-GO decision
└────────┬────────────┘
         │
┌────────▼────────────┐
│  3. Build & Deploy  │  ← Standard deployment (DEV → QA → Prod)
│     (DEV)           │
└────────┬────────────┘
         │
┌────────▼────────────┐
│  4. SRE Post-Deploy │  ← SRE Agent: health check, anomaly detection,
│     Validation      │     baseline comparison
└────────┬────────────┘
         │ (on failure)
┌────────▼────────────┐
│  5. SRE Automated   │  ← SRE Agent: slot swap, AKS rollback, or
│     Rollback        │     agent-selected strategy
└────────┬────────────┘
         │ (on any failure)
┌────────▼────────────┐
│  6. SRE Incident    │  ← SRE Agent: work items, Teams alerts,
│     Response        │     root cause analysis, PagerDuty
└────────┬────────────┘
         │
┌────────▼────────────┐
│  7. AI Post-Build   │  ← AI Agent: build log analysis, pattern
│     Analysis        │     detection, optimization suggestions
└────────┬────────────┘
         │
┌────────▼────────────┐
│  8. SRE Health      │  ← SRE Agent: MTTD/MTTR, deployment scorecard,
│     Report          │     reliability audit, baseline update
└─────────────────────┘
```

The two agents serve different roles at different lifecycle phases:

| Concern | AI Agent | SRE Agent |
|---------|----------|-----------|
| **Scope** | Source code and build artifacts | Live Azure infrastructure |
| **When** | Pre-deploy (code review) and post-deploy (log analysis) | Pre-deploy gate through final health report |
| **Data Sources** | Repository files, build logs, scan results | Azure Monitor, Resource Health, Activity Log, Alerts |
| **Actions** | Advisory (findings, recommendations) | Operational (block deploy, trigger rollback, file incident) |
| **Backing Service** | Azure OpenAI (GPT-4) via AI Foundry | Azure SRE Agent (Microsoft.App/agents) + Azure OpenAI fallback |

---

## Chapter 3: The AI Agent

### Code Intelligence at Build Time

The AI Agent is an Azure OpenAI deployment (`cicd-ai-agent`) accessed through Azure AI Foundry's Responses API. It doesn't have its own resource type in Azure — it's an application endpoint that wraps a GPT-4 model with a project-specific configuration.

#### What it does

The AI Agent performs three categories of analysis, each implemented as a reusable YAML template:

**1. AI Code Review** (`ai-code-review.yml`)

This is the most comprehensive template. It runs a 5-phase analysis:

- **Phase 1: File Collection** — Scans the entire repository for `.ipynb`, `.py`, and `.yml` files. Converts paths to relative format for clean reporting.

- **Phase 2: Security Scanning** — Runs Bandit (Python static analysis) and a custom regex-based secret scanner. The secret scanner checks for API keys, passwords, connection strings, bearer tokens, AWS keys, Azure storage keys, and private key files.

- **Phase 3: Best Practices** — Pattern-matches against a curated list of anti-patterns specific to Databricks/PySpark: SQL injection via f-strings in `spark.sql()`, `.collect()` calls that pull data to the driver, wildcard imports, silent exception swallowing, `print()` instead of proper logging, `.toPandas()` on large datasets, infinite loops, and long sleeps.

- **Phase 4: AI Deep Analysis** — Sends the code samples and automated findings to Azure OpenAI with a detailed system prompt. The prompt instructs the model to review security, performance, code quality, Databricks best practices, and data quality. It asks for structured output with severity-tagged findings (🔴 Critical, 🟡 Warning, 🟢 Suggestion).

- **Phase 5: Report Generation** — Produces a Markdown report published as a pipeline artifact.

The key design decision: automated scanning runs *first*, and its findings are included in the AI prompt as context. This means the AI isn't starting from scratch — it's triaging and interpreting findings that static analysis already identified. This dramatically improves the quality and specificity of the AI output.

**2. AI Build Log Analysis** (`ai-build-log-analysis.yml`)

After deployment completes (or fails), this template fetches the full pipeline timeline via the Azure DevOps REST API, collects the last 100 lines of each task's log output, and sends the combined logs to the AI Agent. The prompt asks for error analysis with root cause identification, warning review, performance issue detection, and best practice recommendations.

This is where the AI Agent earns its keep on failure: instead of scrolling through hundreds of lines of pipeline output, the team gets a structured analysis with specific remediation steps.

**3. AI Resource Optimization** (`ai-resource-optimization.yml`)

This template queries the Databricks workspace API to collect cluster configurations, job definitions, recent run history, instance pools, and SQL warehouses. It sends this data to the AI Agent with a prompt asking for cost optimization, right-sizing recommendations, and efficiency improvements.

#### How authentication works

All AI Agent calls follow the same pattern:

```powershell
# Get Azure ML token (works for AI Foundry endpoints)
$aiToken = az account get-access-token --resource https://ml.azure.com --query accessToken -o tsv

# Call the Responses API
$body = @{ model = "cicd-ai-agent"; input = $prompt } | ConvertTo-Json
Invoke-RestMethod -Uri $endpoint -Method POST -Headers @{
    "Authorization" = "Bearer $aiToken"
    "Content-Type" = "application/json"
} -Body $body
```

The response parsing handles multiple formats (Responses API, Chat Completions, simple text) because the Azure AI Foundry endpoint format has evolved across API versions.

---

## Chapter 4: The Azure SRE Agent

### Infrastructure Intelligence at Deploy Time

The Azure SRE Agent is a fundamentally different beast. It's an actual Azure resource (`Microsoft.App/agents`) — a first-party service currently in preview. It has its own ARM resource type, its own CLI extension (`az extension add --name sre-agent`), and its own REST API.

#### Provisioning

The agent is provisioned via ARM REST API (`sre-agent.ps1`):

```powershell
# The agent resource definition
$payload = @{
    location = "eastus2"
    identity = @{
        type = "SystemAssigned,UserAssigned"
        userAssignedIdentities = @{ $UAMI_ID = @{} }
    }
    properties = @{
        actionConfiguration = @{
            accessLevel = "High"
            mode = "review"        # "review" = recommend only, "autonomous" = act
            identity = $UAMI_ID
        }
        incidentManagementConfiguration = @{
            type = "AzMonitor"
        }
        knowledgeGraphConfiguration = @{
            identity = $UAMI_ID
            managedResources = @(
                "/subscriptions/.../resourceGroups/rg-rkibbe-2470"
            )
        }
        upgradeChannel = "Stable"
    }
}
```

Key configuration decisions:

- **`mode: "review"`** — The agent recommends actions but doesn't execute them autonomously. This is the safe starting point. Switching to `"autonomous"` lets the agent take direct action on your infrastructure.
- **`accessLevel: "High"`** — Gives the agent broad read access to the managed resource scope.
- **`managedResources`** — Specifies which resource groups the agent can observe. This is the blast radius control.
- **User-Assigned Managed Identity (UAMI)** — The agent authenticates using a dedicated identity, not the pipeline's service connection. This provides proper RBAC separation.

#### The Dual-Path Architecture

The implementation uses a clever fallback pattern. Every SRE action first tries the native SRE Agent REST API. If that fails (the service is still in preview, after all), it falls back to Azure OpenAI with SRE-specific system prompts:

```powershell
function Invoke-SREAgentAPI {
    # Try SRE Agent REST API first
    if ($SREAgentName -and $SREAgentResourceGroup) {
        try {
            $sreResponse = Invoke-RestMethod -Uri "$sreApiBase/actions?api-version=2025-05-01-preview" ...
            return $result
        } catch {
            Write-Host "SRE Agent API call failed, falling back to AI agent"
        }
    }

    # Fallback: Azure OpenAI with SRE-specific system prompt
    $sreSystemPrompt = Get-SRESystemPrompt -Action $Action
    # ... call Azure OpenAI ...
}
```

Each SRE action type gets a specialized system prompt:

- **Diagnostics**: Deep resource analysis — health, error rates, latency percentiles, utilization, dependency health, recent changes
- **Readiness**: Pre-deployment assessment — GO/NO-GO with confidence score and risk factors
- **Audit**: Reliability evaluation — SLO compliance, error budgets, configuration drift, security posture
- **Baseline**: Performance comparison — anomaly detection, statistical significance, regression identification
- **Mitigate**: Remediation planning — specific Azure CLI commands, impact assessment, rollback procedures

This dual-path design means the pipeline works today (via the AI fallback) while being ready to leverage native SRE Agent capabilities as the preview matures.

---

## Chapter 5: MCP Servers

### The Connective Tissue

Model Context Protocol (MCP) servers act as the bridge between AI models and external tools/data sources. In this pipeline architecture, MCP plays several roles:

#### 1. Azure Resource Context via MCP

When the AI Agent needs to understand Azure resource topology — what's deployed, how it's configured, what alerts exist — MCP servers provide structured access to Azure Resource Manager, Azure Monitor, and Azure Resource Health APIs. Rather than embedding raw REST calls in prompts, MCP servers expose these as tool calls the model can invoke contextually.

#### 2. Build System Integration

MCP servers can wrap the Azure DevOps REST API, giving the AI Agent structured access to:
- Pipeline run history and trends
- Build timelines and task results
- Work item queries and updates
- Repository metadata

#### 3. Observability Data Pipeline

The SRE Agent's knowledge graph configuration (`knowledgeGraphConfiguration`) is itself an MCP-like pattern: it declares which Azure resources the agent can observe, and the agent uses that scope to query Azure Monitor metrics, Resource Health status, and Activity Log events.

#### How MCP Enhances Semi-Autonomy

Traditional integrations require hardcoded API calls for every data source. MCP inverts this: the model decides what data it needs based on the task context, and MCP servers provide it on demand. This is what enables the "semi-autonomous" behavior — the agents can explore the environment, discover relevant signals, and make decisions without every query being pre-scripted.

In practice, this means the pipeline can adapt to novel failure modes. If a new type of deployment issue arises that wasn't anticipated when the templates were written, the AI Agent can still reason about it because it has access to raw data through MCP, not just pre-formatted summaries.

---

## Chapter 6: Pipeline Design

### Composable Template Architecture

The pipeline uses a composable template architecture where every capability is a standalone YAML template with standardized parameters. This design has three important properties:

#### 1. Every template is independently toggleable

```yaml
parameters:
  - name: run_sre_agent
    type: boolean
    default: true
  - name: sre_pre_deploy_gate
    type: boolean
    default: true
  - name: sre_post_deploy_validation
    type: boolean
    default: true
  - name: sre_automated_rollback
    type: boolean
    default: true
```

Each SRE and AI capability can be turned on or off at pipeline runtime. This is critical for adoption: teams can start with just AI code review, add the pre-deploy gate once they trust it, enable automated rollback once they've validated the detection logic, and so on.

#### 2. Shared helper layer

The `sre-agent-common.yml` template writes a PowerShell helper script to the agent's temp directory, which all subsequent templates dot-source. This provides:

- `Invoke-SREAgentAPI` — Unified API client with native/fallback routing
- `Get-SRESystemPrompt` — Action-specific system prompts
- `Get-AIResponseText` — Response parsing across API formats
- `Get-AzureResourceHealth` — Resource Health API wrapper
- `Get-AzureMonitorMetrics` — Azure Monitor Metrics API wrapper
- `Get-AzureMonitorAlerts` — Alert Management API wrapper
- `Get-AzureActivityLog` — Activity Log API wrapper
- `Format-SREReport` — Standardized report formatting

#### 3. Centralized variables

```yaml
variables:
  - name: azureOpenAIEndpoint
    value: 'https://...services.ai.azure.com/.../responses?api-version=2025-11-15-preview'
  - name: azureOpenAIDeployment
    value: 'cicd-ai-agent'
```

The AI endpoint and deployment name are defined once and passed to every template. This avoids configuration drift when templates are used across multiple pipelines.

---

## Chapter 7: Pre-Deployment

### Readiness Gates and Baseline Capture

Stage 2 of the pipeline is where the SRE Agent earns the "gate" in "readiness gate." Before any code is deployed, three things happen:

#### 1. Environment Readiness Assessment

The pre-deploy gate (`sre-pre-deploy-gate.yml`) builds a readiness score starting at 100 and deducting points for each risk factor:

- **Resource Health Check** — Queries Azure Resource Health for every target resource. Any non-"Available" status is a deduction. "Degraded" loses fewer points than "Unavailable."

- **Active Alert Scan** — Queries Azure Alert Management for fired alerts. Sev0 alerts can block deployment entirely. Multiple Sev1 alerts deduct proportionally.

- **Recent Activity Analysis** — Checks the Azure Activity Log for recent deployments, configuration changes, or delete operations. Recent changes increase risk.

- **SRE Agent Diagnostics** — Sends the collected data to the SRE Agent (or AI fallback) for a holistic readiness assessment. The response includes a GO/NO-GO recommendation.

The final readiness score is compared against the `minimumReadinessScore` parameter (default: 70). If the score is below threshold and `blockOnNoGo` is true, the stage fails and downstream deployment stages are skipped.

#### 2. Baseline Capture

Before deploying, `sre-performance-baseline.yml` runs with `action: 'capture'`. It queries Azure Monitor for key metrics across all target resources:

- Availability
- End-to-end latency (SuccessE2ELatency)
- Server errors
- Transaction counts

For each metric, it calculates statistical properties: average, p50, p95, p99, min, max, standard deviation, and sample count. This snapshot is saved as a JSON artifact and optionally uploaded to blob storage.

This baseline becomes the comparison point for post-deployment validation. If latency goes up 30% after deployment, the pipeline will detect it.

---

## Chapter 8: Post-Deployment

### Validation, Rollback, and Incident Response

The post-deployment phase is where the pipeline's semi-autonomous capabilities are most visible. Three stages work together as a reactive chain:

#### Stage 6: Post-Deploy Validation

After deployment completes, the pipeline waits for a configurable warmup period (default: 120 seconds) to let the new deployment stabilize. Then it runs a multi-step validation:

1. **Resource Health Re-check** — Are all target resources still healthy?
2. **Metrics Snapshot** — Current values for availability, latency, errors
3. **Anomaly Detection** — SRE Agent analyzes metrics for anomalies
4. **Baseline Comparison** — Current metrics vs. pre-deploy baseline. Any metric deviating more than 20% (configurable `regressionThresholdPercent`) flags a regression.

The validation produces a `healthScore` starting at 100 with deductions for each issue. If `failOnUnhealthy` is true and the health score drops below threshold, the stage fails — which triggers the rollback stage.

#### Stage 8: Automated Rollback

This stage only runs when post-deploy validation fails. It supports five rollback strategies:

| Strategy | How it works |
|----------|-------------|
| `slot-swap` | Swaps App Service / Functions deployment slots back to the previous version |
| `aks-rollback` | Runs `kubectl rollout undo` on the specified AKS deployment |
| `revert-deploy` | Queues a re-run of the last successful pipeline build |
| `custom-script` | Executes a user-provided rollback script |
| `sre-agent-auto` | Sends the failure context to the SRE Agent and lets it choose the strategy |

The `sre-agent-auto` option is where the semi-autonomous behavior is most apparent. The SRE Agent receives the full failure context — which resources are unhealthy, what metrics regressed, what changed — and recommends the appropriate rollback strategy. In `review` mode, it recommends. In `autonomous` mode (not yet enabled), it would execute.

#### Stage 9: Incident Response

This stage triggers on *any* failure — deployment failure, validation failure, or even rollback failure. It's the pipeline's "something went wrong, sound the alarm" mechanism:

1. **Root Cause Analysis** — Sends the full incident context to the SRE Agent for analysis. The response identifies likely causes and recommended remediation.

2. **Work Item Creation** — Uses the Azure DevOps REST API to create a Bug work item with the incident details, root cause analysis, severity tag, and links back to the build.

3. **Teams Notification** — Sends an Adaptive Card to a Microsoft Teams channel via webhook. The card includes severity emoji (🔴/🟠/🟡/🔵), incident title, build details, and triggers.

4. **PagerDuty Integration** — Optionally sends a PagerDuty event with severity-mapped urgency levels.

The incident response template is designed to always run (`condition: always()`), even if previous steps failed. This ensures incidents are always captured, regardless of what went wrong.

---

## Chapter 9: Observability

### Health Reports, Baselines, and Reliability Audits

The final stage of the pipeline generates a comprehensive deployment health report. This isn't just a pass/fail summary — it's a deployment scorecard with operational metrics.

#### MTTD / MTTR Calculation

The health report template queries the Azure DevOps timeline API to calculate:

- **MTTD (Mean Time To Detect)** — Approximated as the duration of the post-deploy validation stage. This is the time between deployment completing and an issue being detected.
- **MTTR (Mean Time To Recover)** — Approximated as the total pipeline duration for the fix cycle.

These are imperfect approximations, but they establish a measurement baseline that improves over time as the pipeline collects more data.

#### Deployment Scorecard

```
Pipeline duration: 14.3 min
Stages: 7 passed, 1 failed, 3 skipped
Est. MTTD: 2.1 min
```

The scorecard aggregates results across all stages, providing a single-pane view of deployment health.

#### AI Executive Summary

The health report sends the full pipeline results to the AI Agent with a prompt requesting:
1. Overall health assessment
2. Key risks or issues
3. Recommendations for next deployment
4. Trend observations

This turns raw pipeline data into actionable insights that can be shared with leadership or used in sprint retrospectives.

#### Baseline Update

On successful deployments, the performance baseline is updated with current metrics. This creates a rolling baseline that adapts to organic changes in traffic patterns and infrastructure, reducing false positives in regression detection.

#### Reliability Audit

The final step runs a reliability audit that can also be scheduled independently (nightly/weekly). It evaluates:

- **SLO Compliance** — Current metrics vs. SLO targets (availability 99.9%, p95 latency < 500ms, error rate < 1%)
- **Alert History** — Volume and severity of recent alerts
- **Resource Health Trends** — Historical availability status
- **Error Budget Status** — How much error budget remains

---

## Chapter 10: Semi-Autonomous

### The Trust Spectrum

"Semi-autonomous" is a deliberate design choice, not a limitation. The pipeline operates on a trust spectrum:

#### Level 1: Advisory Only
- AI code review provides recommendations (engineer decides)
- SRE health reports summarize status (team decides next steps)
- Build log analysis highlights problems (engineer investigates)

#### Level 2: Gated Automation
- Pre-deploy gate blocks deployment on NO-GO (but can be overridden)
- Post-deploy validation flags unhealthy deployments (rollback is automatic *but* requires `sre_automated_rollback: true`)
- Incident response creates work items and notifications (but doesn't assign or escalate)

#### Level 3: Supervised Autonomy
- SRE Agent in `review` mode recommends rollback strategy (human approves)
- `sre-agent-auto` strategy lets the agent choose the rollback approach
- Agent creates and triages incidents, recommends remediation

#### Level 4: Full Autonomy (Future)
- SRE Agent in `autonomous` mode executes remediation directly
- Auto-scaling based on baseline deviations
- Self-healing infrastructure responses

The current implementation operates at **Level 2-3**. Every parameter has a safe default. Every autonomous action has a toggle. The pipeline is designed to earn trust incrementally:

```yaml
# Start conservative
sre_block_on_no_go: true         # Block deploys, but you can override
sre_fail_on_unhealthy: true      # Flag failures, trigger rollback chain
sre_automated_rollback: true     # But rollback strategy is explicit
sre_rollback_strategy: 'slot-swap'  # Predictable, reversible action

# Graduate to semi-autonomous
sre_rollback_strategy: 'sre-agent-auto'  # Let the agent choose

# Eventually
# actionConfiguration.mode: 'autonomous'  # Let the agent act
```

---

## Chapter 11: Lessons Learned

### What Worked

**1. The dual-agent architecture**: Separating code-level and infrastructure-level concerns into distinct agents with different backing services was the right call. They have different data sources, different action scopes, and different trust profiles. Forcing them into a single model would have produced worse results for both.

**2. The fallback pattern**: Having Azure OpenAI as a fallback for the SRE Agent REST API means the pipeline works today, even when the preview service has hiccups. The SRE-specific system prompts in the fallback path produce remarkably good results — they're not as good as the native agent's knowledge graph, but they're good enough to gate deployments.

**3. Composable toggles**: Making every feature independently toggleable (30+ boolean parameters) initially felt like over-engineering. In practice, it was essential. Teams adopt these capabilities in different orders at different speeds. The inability to turn off one feature without affecting others would have blocked adoption entirely.

**4. Statistical baselines over hard thresholds**: Using p50/p95/p99 with standard deviation for baseline comparison, rather than fixed thresholds, dramatically reduced false positives. The system learns what "normal" looks like for each resource and adapts.

### What's Next

**1. Multi-environment baseline correlation**: Currently, each environment (dev/qa/prod) has independent baselines. Correlating patterns across environments (e.g., "this regression appeared in dev 3 days before hitting prod") would enable predictive gating.

**2. Feedback loops**: The AI code review findings should feed back into the best practices pattern list. If the AI consistently flags a pattern that the static scanner misses, that pattern should be added to the automated checks.

**3. Cost attribution**: The AI Resource Optimization template already collects cluster and job data. Adding cost data from Azure Cost Management would enable ROI calculations: "This pipeline run prevented a $X outage by detecting Y before deployment."

**4. Autonomous mode**: The SRE Agent's `autonomous` mode is the logical next step. Start with low-risk actions (creating incidents, adjusting alert thresholds) before graduating to infrastructure changes (scaling, failover).

---

## Appendix A: Template Reference

| Template | Agent | Purpose |
|----------|-------|---------|
| `ai-code-review.yml` | AI | Security scan, best practices, AI code review |
| `ai-build-log-analysis.yml` | AI | Post-build log analysis and root cause |
| `ai-smoke-test.yml` | AI | AI-validated smoke tests on Databricks |
| `ai-resource-optimization.yml` | AI | Databricks workspace optimization recommendations |
| `ai-generate-databricks-yml.yml` | AI | Auto-generate Databricks bundle YAML |
| `ai-test-generation.yml` | AI | Auto-generate tests for notebooks |
| `sre-agent-common.yml` | SRE | Shared helpers, auth, API wrappers |
| `sre-pre-deploy-gate.yml` | SRE | Pre-deployment readiness assessment |
| `sre-post-deploy-validation.yml` | SRE | Post-deployment health validation |
| `sre-automated-rollback.yml` | SRE | Automated rollback on failure |
| `sre-incident-response.yml` | SRE | Incident creation, notification, RCA |
| `sre-performance-baseline.yml` | SRE | Baseline capture, compare, update |
| `sre-health-report.yml` | SRE | Deployment scorecard and executive summary |
| `sre-reliability-audit.yml` | SRE | SLO compliance and reliability evaluation |
| `security-scan.yml` | — | Bandit static analysis (no AI) |
| `osv-dependency-scan.yml` | AI | OSV vulnerability scan with AI triage |

## Appendix B: Key Configuration

```yaml
# Azure OpenAI (AI Agent)
azureOpenAIEndpoint: 'https://...services.ai.azure.com/.../responses?api-version=2025-11-15-preview'
azureOpenAIDeployment: 'cicd-ai-agent'

# Azure SRE Agent
sre_agent_resource_group: 'rg-rkibbe-2470'
sre_agent_name: 'rkibbe'
sre_agent_endpoint: 'https://rkibbe--88208374.4650bed8.eastus2.azuresre.ai'

# SRE Agent Identity (agent.json)
actionConfiguration.mode: 'review'          # review | autonomous
actionConfiguration.accessLevel: 'High'
incidentManagementConfiguration.type: 'AzMonitor'
upgradeChannel: 'Stable'
```

---

*This guide is based on a working implementation. All templates, scripts, and configurations referenced are real and in production use. The Azure SRE Agent is in preview — API versions and capabilities may change.*
