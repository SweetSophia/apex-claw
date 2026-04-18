# ClawDeck Advancement Plan

**Created**: 2026-04-16 | **Status**: In Progress
**Repo**: SweetSophia/clawdeck (independently maintained)

## Overview
Transform ClawDeck from a basic fleet skeleton into a production-grade AI agent orchestration platform.

---

## Phase 1: Go Agent Runtime 🔄
**Branch**: `feat/phase1-agent-runtime`

### 1.1 Real Executor Framework ✅ (commit `57f8994`)
- [x] Replace `StubExecutor` with pluggable `Executor` interface
- [x] Implement `ShellExecutor` — execute shell commands with allowlist
- [x] Implement `ScriptExecutor` — multi-line bash scripts
- [x] Executor registry — config-driven selection per task type
- [x] Context propagation (timeout, cancellation) through executor chain
- [x] Tests for each executor (15 total)

### 1.2 Enhanced Heartbeat ✅ (commit `d6be91f`)
- [x] Handle `desired_state` actions: drain, restart, shutdown
- [x] Drain mode: stop accepting tasks, finish current, idle
- [x] Graceful shutdown on SIGTERM/SIGINT (30s timeout)
- [ ] Configurable heartbeat interval via API response (deferred)
- [x] Metadata enrichment: task_runner_active, draining, uptime_seconds

### 1.3 Retry & Backoff ✅ (commit `3233fe9`)
- [x] Exponential backoff on task failures (configurable base/max)
- [x] Max retry count per task (default 3)
- [x] Reports failed state after max retries exhausted
- [x] ±25% jitter to prevent thundering herd

### 1.4 Structured Logging ✅ (commit `3233fe9`)
- [x] JSON log format with: timestamp, level, agent_id, task_id
- [x] Log level configuration via CLAWDECK_LOG_LEVEL env var
- [x] Global logger via InitLogger(agentID)

---

## Phase 2: Rails API Hardening 🔐
**Branch**: `feat/phase2-api-hardening`

### 2.1 Token Rotation & Revocation ✅ (commit `9be78d0`)
- [x] `POST /api/v1/agents/:id/rotate_token` — issue new token, invalidate old
- [x] `POST /api/v1/agents/:id/revoke_token` — immediate invalidation
- [x] Token expiry support (TTL field on agent_tokens)
- [x] Automatic rotation prompt on heartbeat if token near expiry

### 2.2 Audit Logging ✅ (commit `95faf0a`)
- [x] `AuditLog` model: actor_type, actor_id, action, resource, changes, ip
- [x] Concern: `Auditable` — auto-logs CRUD on included models
- [x] API endpoint: `GET /api/v1/audit_logs` (admin only)
- [ ] UI: Admin audit log viewer (deferred to Phase 4)

### 2.3 Per-Agent Rate Limiting ✅ (commit `86f94ca`)
- [x] `RateLimit` model: agent_id, window_seconds, max_requests
- [x] Rack middleware: token-bucket per agent
- [x] `429 Too Many Requests` with `Retry-After` header
- [x] Configurable defaults per agent tier

### 2.4 Real-Time Updates ✅ (commit `fcecd61`)
- [x] Turbo Streams broadcast on: task create/update/complete, agent status change
- [x] SSE endpoint for API consumers
- [x] Agent presence indicators on dashboard

---

## Phase 3: Agent Intelligence 🧠
**Branch**: `feat/phase3-intelligence`

### 3.1 Command Handlers ✅ (commit `93d2592`)
- [x] `upgrade` — graceful self-update (download new binary, restart)
- [x] `drain` — stop accepting tasks
- [x] `config_reload` — hot-reload agent config
- [x] `shell` — execute shell command with allowlist enforcement
- [x] `health_check` — return detailed health diagnostics

### 3.2 Task Artifacts ✅ (commit `63faa86`)
- [x] `TaskArtifact` model: task_id, filename, content_type, size, storage_path
- [x] Upload endpoint: `POST /api/v1/tasks/:id/artifacts`
- [x] Download endpoint: `GET /api/v1/tasks/:id/artifacts/:artifact_id`
- [x] Active Storage integration for file storage

### 3.3 Agent-to-Agent Handoff ✅ (commit `63faa86`)
- [x] `TaskHandoff` model: from_agent_id, to_agent_id, task_id, context, status
- [x] API: `POST /api/v1/tasks/:id/handoff` with target agent + context
- [x] Go client: `HandoffTask(ctx, taskID, targetAgentID, context)` method
- [x] Handoff approval flow (optional: target must accept)

---

## Phase 4: Polish ✨
**Branch**: `feat/phase4-polish`

### 4.1 Dashboard Enhancements
- [x] Agent health cards (uptime, task throughput, error rate)
- [ ] Task timeline/Gantt view
- [ ] Real-time metrics via Turbo Streams
- [ ] Command bar improvements (natural language task creation)

### 4.2 Documentation
- [x] README — architecture, setup, screenshots
- [ ] API reference (OpenAPI/Swagger)
- [x] Deployment guide (Docker, bare metal)
- [ ] Agent SDK docs (Go client library)

### 4.3 Integration Tests
- [x] Full E2E cycle: register → heartbeat → get task → execute → complete
- [x] Command flow: issue command → ack → complete
- [x] Failure scenarios: token revocation/rejection, handoff rejection, artifact validation failures
- [ ] Load test: concurrent agents with rate limiting

---

## Execution Strategy

| Phase | Model | Approach |
|-------|-------|----------|
| Phase 1 (Go) | GLM-5.1 subagent | Go expertise, runtime code |
| Phase 2 (Rails) | GPT-5.4 subagent | Rails conventions, security |
| Phase 3 (Mixed) | Both models | Split Go vs Rails work |
| Phase 4 (Polish) | GLM-5.1 | Docs + tests |

**Workflow per item:**
1. Create feature branch
2. Implement + test
3. GLM-5.1 review pass
4. Merge to main
5. Document in Noosphere wiki
6. Update this checklist

---

## Progress Log

| Date | Item | Status | Notes |
|------|------|--------|-------|
| 2026-04-16 | 1.1 Executor Framework | ✅ | GLM-5.1, 15 tests, commit 57f8994 |
| 2026-04-16 | 2.2 Audit Logging | ✅ | GPT-5.4, 6 tests, 147 total Rails, commit 95faf0a |
| 2026-04-16 | 1.3 Retry/Backoff + 1.4 Logging | ✅ | GPT-5.4, commit 3233fe9 |
| 2026-04-16 | 1.2 Enhanced Heartbeat | ✅ | GLM-5.1, commit d6be91f |
| 2026-04-16 | 2.2 Audit Logging fixup | ✅ | commit 6b37448 |
| 2026-04-16 | 2.1 Token Rotation | ✅ | GPT-5.4, expiry+revoke+rotate endpoints, Go client, commit 9be78d0 |
| 2026-04-16 | 2.3 Rate Limiting | ✅ | GPT-5.4, token-bucket middleware, 429s, rate headers, commit 86f94ca |
| 2026-04-16 | 2.4 Real-Time Updates | ✅ | GLM-5.1, Turbo Streams + SSE + Stimulus controllers, commit fcecd61 |
| 2026-04-16 | 3.1 Command Handlers | ✅ | GPT-5.4, drain/health/shell/config/upgrade handlers, commit 93d2592 |
| 2026-04-16 | 3.2 Task Artifacts | ✅ | GPT-5.4, upload/download/list, Active Storage, Go client, commit 63faa86 |
| 2026-04-16 | 3.3 Agent Handoff | ✅ | GLM-5.1, handoff with context, accept/reject/expiry, Go client, commit 63faa86 |
| 2026-04-18 | 4.1 Agent Health Cards | ✅ | dashboard health badges/stats, tests green, commit 2edbe44 |
| 2026-04-18 | 4.2 Docs refresh | ✅ | standalone positioning, honest quickstart/deploy docs, commits 54f7ebd/2bab8d5/550e647/948c7ca/c8ce2df |
| 2026-04-18 | 4.3 Integration tests | ✅ | lifecycle, commands, token rotation/revocation, handoffs, artifacts, SSE payload assertion, commits 2ef45e4/e9d8b30/1b05696/5a486ee |
