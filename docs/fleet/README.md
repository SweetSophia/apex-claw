# Apex Claw Fleet Architecture

This document summarizes the current fleet architecture for Apex Claw.

## Goal

Apex Claw acts as a control plane for managing AI agents that register, heartbeat, receive commands, claim work, and report results safely.

## Control Plane vs Data Plane

### Control Plane (Rails app)

The Rails app owns:
- user accounts and boards
- task lifecycle and assignment
- agent registration and token management
- command queueing
- handoffs and artifacts
- audit logging and rate limiting
- live dashboard updates through Turbo Streams and SSE

### Data Plane (Go runtime)

The Go agent runtime owns:
- registration via join token
- persistent agent token usage
- heartbeat loop
- task polling and execution
- command polling and execution
- artifact upload and handoff participation
- graceful drain / restart / runtime state changes

## Current Implemented Capabilities

### Agent identity and auth
- first-class `Agent` model
- digest-backed `AgentToken` auth
- one-time `JoinToken` registration flow
- token rotation and revocation

### Agent lifecycle
- registration endpoint
- heartbeat endpoint
- desired-state response payload
- richer metadata tracking such as uptime and runner state
- configurable heartbeat interval shipped in PR #13 (`3c51cc7`)

### Task execution surface
- agent-scoped `/tasks/next`
- claim / unclaim flows
- task output updates
- artifact upload
- agent-to-agent handoff

### Command surface
- queued agent commands
- acknowledge / complete lifecycle
- runtime handlers for drain, resume, restart, upgrade, config reload, shell, and health checks

### UI and observability
- live agent dashboard
- health cards
- task timeline / Gantt view
- real-time dashboard metrics
- command palette and deep links
- admin audit log UI

## Concurrency and safety model

Task dispatch and claim flows use database-backed concurrency protection so two agents do not take the same work.

The important ideas are:
- agent-scoped access
- ownership checks
- row-lock based claim safety
- draining agents stop receiving new tasks

## Documentation map

For day-to-day work, pair this file with:

- `README.md`
- `docs/AGENT_INTEGRATION.md`
- `docs/api/OPENAPI_REFERENCE.md`
- `docs/sdk/GO_AGENT_SDK.md`
- `docs/fleet/SECURITY.md`

## What is still open?

The core fleet implementation is complete.

Remaining follow-ups are now limited to:
- routine maintenance and future fleet/runtime improvements
- auditing deployment/runtime assumptions on a real VPS
- reviewing the remaining lower-priority security cleanup items outside the deployment path
