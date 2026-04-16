# ClawDeck Advancement Plan

**Created**: 2026-04-16 | **Status**: In Progress
**Repo**: SweetSophia/clawdeck (fork of abandoned clawdeckio/clawdeck)

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

### 1.2 Enhanced Heartbeat
- [ ] Handle `desired_state` actions: `upgrade`, `drain`, `restart`, `shutdown`
- [ ] Drain mode: stop accepting new tasks, finish current, then idle
- [ ] Graceful shutdown on SIGTERM/SIGINT
- [ ] Configurable heartbeat interval via API response
- [ ] Metadata enrichment: task queue depth, current task progress

### 1.3 Retry & Backoff
- [ ] Exponential backoff on task failures (configurable base/max)
- [ ] Max retry count per task (server-side field)
- [ ] Dead letter marking after max retries exhausted
- [ ] Backoff state persisted (survives restart)

### 1.4 Structured Logging
- [ ] JSON log format with: timestamp, level, agent_id, task_id, correlation_id
- [ ] Log level configuration via env var
- [ ] Log rotation support

---

## Phase 2: Rails API Hardening 🔐
**Branch**: `feat/phase2-api-hardening`

### 2.1 Token Rotation & Revocation
- [ ] `POST /api/v1/agents/:id/rotate_token` — issue new token, invalidate old
- [ ] `POST /api/v1/agents/:id/revoke_token` — immediate invalidation
- [ ] Token expiry support (TTL field on agent_tokens)
- [ ] Automatic rotation prompt on heartbeat if token near expiry

### 2.2 Audit Logging ✅ (commit `95faf0a`)
- [x] `AuditLog` model: actor_type, actor_id, action, resource, changes, ip
- [x] Concern: `Auditable` — auto-logs CRUD on included models
- [x] API endpoint: `GET /api/v1/audit_logs` (admin only)
- [ ] UI: Admin audit log viewer (deferred to Phase 4)

### 2.3 Per-Agent Rate Limiting
- [ ] `RateLimit` model: agent_id, window_seconds, max_requests
- [ ] Rack middleware: token-bucket per agent
- [ ] `429 Too Many Requests` with `Retry-After` header
- [ ] Configurable defaults per agent tier

### 2.4 Real-Time Updates
- [ ] Turbo Streams broadcast on: task create/update/complete, agent status change
- [ ] SSE endpoint for API consumers
- [ ] Agent presence indicators on dashboard

---

## Phase 3: Agent Intelligence 🧠
**Branch**: `feat/phase3-intelligence`

### 3.1 Command Handlers
- [ ] `upgrade` — graceful self-update (download new binary, restart)
- [ ] `drain` — stop accepting tasks
- [ ] `config_reload` — hot-reload agent config
- [ ] `shell` — execute shell command with allowlist enforcement
- [ ] `health_check` — return detailed health diagnostics

### 3.2 Task Artifacts
- [ ] `TaskArtifact` model: task_id, filename, content_type, size, storage_path
- [ ] Upload endpoint: `POST /api/v1/tasks/:id/artifacts`
- [ ] Download endpoint: `GET /api/v1/tasks/:id/artifacts/:artifact_id`
- [ ] Active Storage integration for file storage

### 3.3 Agent-to-Agent Handoff
- [ ] `TaskHandoff` model: from_agent_id, to_agent_id, task_id, context, status
- [ ] API: `POST /api/v1/tasks/:id/handoff` with target agent + context
- [ ] Go client: `HandoffTask(ctx, taskID, targetAgentID, context)` method
- [ ] Handoff approval flow (optional: target must accept)

---

## Phase 4: Polish ✨
**Branch**: `feat/phase4-polish`

### 4.1 Dashboard Enhancements
- [ ] Agent health cards (uptime, task throughput, error rate)
- [ ] Task timeline/Gantt view
- [ ] Real-time metrics via Turbo Streams
- [ ] Command bar improvements (natural language task creation)

### 4.2 Documentation
- [ ] Fork README — architecture, setup, screenshots
- [ ] API reference (OpenAPI/Swagger)
- [ ] Deployment guide (Docker, bare metal)
- [ ] Agent SDK docs (Go client library)

### 4.3 Integration Tests
- [ ] Full E2E cycle: register → heartbeat → get task → execute → complete
- [ ] Command flow: issue command → ack → complete
- [ ] Failure scenarios: task failure + retry, agent disconnect, token expiry
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
| 2026-04-16 | 1.1 Executor Framework | ✅ | GLM-5.1 subagent, 15 tests, commit 57f8994 |
| 2026-04-16 | 2.2 Audit Logging | ✅ | GPT-5.4 subagent, model+concern+API, commit 95faf0a |
