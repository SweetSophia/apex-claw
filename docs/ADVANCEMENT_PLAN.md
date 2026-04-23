# Apex Claw Advancement Plan

**Created**: 2026-04-16  
**Status**: All four phases are complete. The previously final planned backlog item, configurable heartbeat interval, shipped in **PR #13** (`3c51cc7`).  
**Repo**: SweetSophia/clawdeck (independently maintained)

## Overview

Transform Apex Claw from a basic fleet skeleton into a production-grade AI agent orchestration platform.

---

## Phase 1: Go Agent Runtime ✅
**Branch**: `feat/phase1-agent-runtime`

### 1.1 Real Executor Framework ✅ (commit `57f8994`)
- [x] Replace `StubExecutor` with pluggable `Executor` interface
- [x] Implement `ShellExecutor`
- [x] Implement `ScriptExecutor`
- [x] Executor registry for task-type selection
- [x] Context propagation through executor chain
- [x] Tests for each executor

### 1.2 Enhanced Heartbeat ✅ (commits `d6be91f`, `3c51cc7`)
- [x] Handle `desired_state` actions: drain, restart, shutdown
- [x] Drain mode: stop accepting tasks, finish current, idle
- [x] Graceful shutdown on SIGTERM/SIGINT
- [x] Configurable heartbeat interval via API response
- [x] Metadata enrichment: task_runner_active, draining, uptime_seconds

### 1.3 Retry & Backoff ✅ (commit `3233fe9`)
- [x] Exponential backoff on task failures
- [x] Max retry count per task
- [x] Reports failed state after retries are exhausted
- [x] ±25% jitter to prevent thundering herd

### 1.4 Structured Logging ✅ (commit `3233fe9`)
- [x] JSON log format with timestamp, level, agent_id, task_id
- [x] Log level configuration via `APEX_CLAW_LOG_LEVEL` (legacy `CLAWDECK_LOG_LEVEL` still supported)
- [x] Global logger via `InitLogger(agentID)`

---

## Phase 2: Rails API Hardening ✅
**Branch**: `feat/phase2-api-hardening`

### 2.1 Token Rotation & Revocation ✅ (commit `9be78d0`)
- [x] `POST /api/v1/agents/:id/rotate_token`
- [x] `POST /api/v1/agents/:id/revoke_token`
- [x] Token expiry support
- [x] Rotation prompting support on heartbeat

### 2.2 Audit Logging ✅ (commit `95faf0a`)
- [x] `AuditLog` model and `Auditable` concern
- [x] Admin API access for audit logs
- [x] Admin UI completed in Sprint D

### 2.3 Per-Agent Rate Limiting ✅ (commit `86f94ca`)
- [x] Token-bucket style rate limiting
- [x] `429 Too Many Requests` with `Retry-After`
- [x] Configurable defaults per agent tier

### 2.4 Real-Time Updates ✅ (commit `fcecd61`)
- [x] Turbo Streams dashboard updates
- [x] SSE endpoint for API consumers
- [x] Agent presence indicators

---

## Phase 3: Agent Intelligence ✅
**Branch**: `feat/phase3-intelligence`

### 3.1 Command Handlers ✅ (commit `93d2592`)
- [x] `upgrade`
- [x] `drain`
- [x] `config_reload`
- [x] `shell`
- [x] `health_check`

### 3.2 Task Artifacts ✅ (commit `63faa86`)
- [x] `TaskArtifact` model
- [x] Upload endpoint
- [x] Download endpoint
- [x] Active Storage integration

### 3.3 Agent-to-Agent Handoff ✅ (commit `63faa86`)
- [x] `TaskHandoff` model
- [x] Handoff API
- [x] Go client support
- [x] Optional accept / reject flow

---

## Phase 4: Polish ✅
**Branch**: `feat/phase4-polish`

### 4.1 Dashboard Enhancements ✅
- [x] Agent health cards
- [x] Task timeline / Gantt view
- [x] Real-time dashboard metrics
- [x] Command palette overhaul

### 4.2 Documentation ✅
- [x] README refresh
- [x] API reference
- [x] Deployment guide
- [x] Go SDK docs

### 4.3 Integration Tests ✅
- [x] Full E2E lifecycle coverage
- [x] Command flow coverage
- [x] Failure path coverage
- [x] Concurrent-agent load test

---

## Post-Phase Backlog

### Product backlog
- [x] Configurable heartbeat interval via API response *(shipped in PR #13 / `3c51cc7`)*

### Ops hardening
- [x] Remove root-owned app service defaults from checked-in systemd units
- [x] Make VPS bootstrap create and use a dedicated app runtime user
- [x] Replace hardcoded nginx/certbot domains with env-driven install-time rendering
- [x] Align production env example, Action Mailer, and host authorization around env-driven host settings
- [x] Align production database wiring with split `CACHE_DATABASE_URL` / `QUEUE_DATABASE_URL` / `CABLE_DATABASE_URL` fallbacks

### Remaining lower-priority follow-up
- [ ] Audit remaining deployment/runtime assumptions on a real VPS
- [ ] Review remaining security cleanup items outside the deployment path

---

## What is still open?

There are **no open phases** left in the plan.

The remaining work intentionally excludes the higher-risk runtime rename surfaces that still use `clawdeck` identifiers today (for example repo naming, deployment paths, runtime usernames, database names, and compatibility fallbacks). Those are deferred rebrand tasks, not missing low-risk doc cleanup.

What remains is narrower than phase work:

1. Audit production/runtime behavior on a real VPS
2. Review remaining non-deployment security cleanup items
3. Continue low-risk rebrand and documentation cleanup work

---

## Progress Log

| Date | Item | Status | Notes |
|------|------|--------|-------|
| 2026-04-16 | 1.1 Executor Framework | ✅ | commit `57f8994` |
| 2026-04-16 | 1.2 Enhanced Heartbeat | ✅ | commit `d6be91f` |
| 2026-04-16 | 1.3 Retry/Backoff + 1.4 Logging | ✅ | commit `3233fe9` |
| 2026-04-16 | 2.1 Token Rotation | ✅ | commit `9be78d0` |
| 2026-04-16 | 2.2 Audit Logging | ✅ | commits `95faf0a` / `6b37448` |
| 2026-04-16 | 2.3 Rate Limiting | ✅ | commit `86f94ca` |
| 2026-04-16 | 2.4 Real-Time Updates | ✅ | commit `fcecd61` |
| 2026-04-16 | 3.1 Command Handlers | ✅ | commit `93d2592` |
| 2026-04-16 | 3.2 Task Artifacts + 3.3 Handoff | ✅ | commit `63faa86` |
| 2026-04-18 | 4.1 Agent Health Cards | ✅ | commit `2edbe44` |
| 2026-04-18 | 4.2 Docs refresh | ✅ | commits `54f7ebd` / `2bab8d5` / `550e647` / `948c7ca` / `c8ce2df` |
| 2026-04-18 | 4.3 Integration tests | ✅ | commits `2ef45e4` / `e9d8b30` / `1b05696` / `5a486ee` |
| 2026-04-18 | Sprint A docs + load test | ✅ | merged to main in `daabb66` / `c792c39` |
| 2026-04-19 | Sprint B timeline/Gantt | ✅ | merged to main in `c6102e6` |
| 2026-04-19 | Sprint C real-time metrics | ✅ | merged to main in `c3974b0` |
| 2026-04-19 | Sprint D admin audit log UI | ✅ | merged to main in `93b4c0d` |
| 2026-04-19 | Sprint E command palette | ✅ | merged across PR #9 / #10 / #11 |
| 2026-04-20 | Ops hardening | ✅ | merged in PR #12 |
| 2026-04-23 | Configurable heartbeat interval | ✅ | shipped in PR #13 (`3c51cc7`) |
