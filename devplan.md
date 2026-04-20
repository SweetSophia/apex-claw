# ClawDeck Development Notes

This file replaces the old local-only **UberClawControl** planning manifest that no longer reflects the state of this repository.

## Current authoritative docs

Use these files instead of the old fork-era planning notes:

- `docs/ADVANCEMENT_PLAN.md` — roadmap, delivery history, and remaining follow-ups
- `README.md` — product overview and local setup
- `QUICKSTART.md` — fastest local bootstrap path
- `DEPLOYMENT.md` — current VPS deployment flow
- `docs/AGENT_INTEGRATION.md` — workflow-oriented agent integration guide
- `docs/api/OPENAPI_REFERENCE.md` — API reference
- `docs/sdk/GO_AGENT_SDK.md` — Go client guide
- `docs/fleet/README.md` — control-plane and runtime architecture
- `docs/fleet/SECURITY.md` — fleet and API security notes

## Project state

As of **April 20, 2026**:

- all four advancement phases are complete
- Sprint A through Sprint E are complete
- ops hardening is complete
- the final planned backlog item, configurable heartbeat interval, is implemented in **PR #13** and awaiting merge
- the remaining open work is limited to two low-priority follow-ups:
  - real VPS deployment/runtime audit
  - review of remaining non-deployment security cleanup items

## Historical note

The previous contents of this file described a local-first future fork plan under the name **UberClawControl**. That document became misleading once ClawDeck was adopted as the independently maintained primary repository and the multi-phase implementation work was completed here.

Keeping this file as a short redirect is intentional, so readers do not mistake the old manifest for the current roadmap.
