# Apex Claw Fleet Security Notes

This document covers the current security posture of Apex Claw's agent and fleet surface.

## Current security model

Apex Claw separates human and agent access clearly:

- **user API tokens** authenticate the owning user
- **agent tokens** authenticate a specific registered agent
- **join tokens** bootstrap one-time registration

## Token storage and lifecycle

### Token types

| Token type | Storage | Use |
| --- | --- | --- |
| Join token | SHA-256 digest only | Single-use agent registration bootstrap |
| Agent token | SHA-256 digest only | Ongoing agent authentication |
| API token | legacy user token path | User API access |

### Implemented protections

- join tokens are single-use
- join tokens and agent tokens are stored as digests, not plaintext
- token comparisons are designed for safe authentication paths
- agent tokens track usage metadata
- token rotation and revocation endpoints are implemented

## Access isolation

The authenticated principal always scopes access:

- user-token requests operate within `current_user`
- agent-token requests operate within `current_agent` and that agent's owner scope

This prevents cross-user access to:
- tasks
- agents
- commands
- handoffs
- artifacts

## Command safety

Implemented command handling includes validation around known command kinds.

Current command surface includes:
- `drain`
- `resume`
- `restart`
- `upgrade`
- `config_reload`
- `shell`
- `health_check`

Security review follow-ups already addressed in the codebase include:
- shell injection hardening
- filename sanitization
- file size limits
- race-condition fixes in command and artifact flows

## Auditability and rate limiting

Implemented in the current codebase:
- audit logging for important system changes
- admin audit log UI
- per-agent rate limiting with `429` responses and `Retry-After`

## Concurrency safety

Task claim and scheduling flows use database-backed locking to reduce double-dispatch risk.

Key protections:
- atomic claim behavior
- ownership validation
- draining agents excluded from new task pickup

## Remaining lower-priority follow-ups

The high-value fleet security work is done.

What remains is narrower:
- review remaining non-deployment security cleanup items outside the deployment path
- validate deployment/runtime assumptions against a real VPS environment

## Related docs

- `docs/fleet/README.md`
- `docs/AGENT_INTEGRATION.md`
- `docs/api/OPENAPI_REFERENCE.md`
- `docs/sdk/GO_AGENT_SDK.md`
- `docs/ADVANCEMENT_PLAN.md`
