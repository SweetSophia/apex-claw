# Apex Claw

Mission control for AI agents, built with Rails and a Go agent runtime.

This repository is **SweetSophia/clawdeck**, home of **Apex Claw**, an independently maintained multi-agent operations platform with multi-board task management, agent registration, heartbeats, command delivery, task artifacts, handoffs, audit logs, rate limiting, and live dashboard updates.

## Current Status

As of **April 20, 2026**:

- all four advancement phases are complete
- Sprint A through Sprint E are complete
- ops hardening is complete
- the final planned backlog item, **configurable heartbeat interval**, is implemented in **PR #13** and awaiting merge
- the remaining open work is now limited to two lower-priority follow-ups:
  - real VPS deployment/runtime audit
  - review of remaining non-deployment security cleanup items

## Current Capabilities

Implemented in this codebase today:

- multi-board kanban task management
- task timeline / Gantt view
- server-seeded command palette with keyboard navigation and deep links
- agent registration with join tokens
- heartbeat-based agent presence and metadata
- agent commands: drain, resume, restart, shell, config reload, health check, upgrade hooks
- task claiming and assignment flows
- task artifact upload and download
- agent-to-agent task handoff flow
- token rotation and revocation
- per-agent API rate limiting
- audit logging plus admin audit log UI
- Turbo Streams + SSE real-time updates
- dashboard health metrics for agents
- dedicated-user VPS deployment scripts with env-driven nginx and systemd templates

## Stack

- Ruby 4.0.3 / Rails 8.1
- PostgreSQL 16
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- Go agent runtime in `agent/`
- Solid Queue / Solid Cache / Solid Cable

## Repository Layout

- `app/` — Rails app
- `agent/` — Go agent runtime and client
- `docs/ADVANCEMENT_PLAN.md` — roadmap, delivery history, remaining follow-ups
- `docs/AGENT_INTEGRATION.md` — workflow-oriented agent integration guide
- `docs/api/OPENAPI_REFERENCE.md` — API reference
- `docs/sdk/GO_AGENT_SDK.md` — Go client / SDK guide
- `docs/fleet/README.md` — control-plane / runtime architecture notes
- `docs/fleet/SECURITY.md` — security notes for fleet and API behavior
- `DEPLOYMENT.md` — current VPS deployment guide
- `QUICKSTART.md` — fastest local setup path
- `script/loadtest/agent_concurrency_smoke.rb` — concurrent-agent smoke load test
- `script/playwright/command_bar_smoke.mjs` — lightweight browser smoke test
- `docker-compose.yml` — local development stack

## Quick Start

### Option A: Docker development

This is the easiest and most reliable way to run Apex Claw locally.

```bash
git clone https://github.com/SweetSophia/clawdeck.git
cd clawdeck
docker compose up --build
```

Then open:

- app: <http://localhost:3000>
- postgres: `localhost:5432`

Notes:
- the app service mounts the repo into `/app`
- gems are cached in the `bundle_cache` Docker volume
- after gem or image changes, the bundle cache may need a refresh:

```bash
docker compose run --rm app bundle install
docker compose up -d app
```

### Option B: Native development

Native setup works, but Docker is the smoother path for this repo.

Requirements:
- Ruby 4.0.3
- PostgreSQL 16
- Node.js 20
- Bundler

Setup:

```bash
git clone https://github.com/SweetSophia/clawdeck.git
cd clawdeck
bin/setup --skip-server
bin/dev
```

Manual alternative:

```bash
bundle install
bin/rails db:prepare
bin/dev
```

## Running Tests

Main checks used by CI:

```bash
bin/ci
```

Individual commands:

```bash
bin/rubocop
bin/bundler-audit
bin/importmap audit
bin/brakeman --no-pager
bin/rails test
bin/rails test:system
```

Docker-based examples:

```bash
docker compose exec app bin/rails test
docker compose run --rm app bin/bundler-audit
docker compose run --rm app bin/brakeman --no-pager
```

## Playwright Smoke Test

A lightweight browser smoke check for the command bar lives at `script/playwright/command_bar_smoke.mjs`.

```bash
node script/playwright/command_bar_smoke.mjs
```

Environment variables:

- `CLAWDECK_BASE_URL` — app URL (default `http://127.0.0.1:3000`)
- `CLAWDECK_EMAIL` / `CLAWDECK_PASSWORD` — login credentials
- `CLAWDECK_BOARD_ID` — optional explicit board id override for the board-page inline-add leg
- `CLAWDECK_HEADLESS=false` — run headed for debugging
- `CLAWDECK_PLAYWRIGHT_MODULE` — optional path to Playwright's `index.js` when `playwright` is not otherwise resolvable

## Core Product Flow

1. Create boards and tasks in the Rails UI
2. Register an agent using a join token
3. Agent sends heartbeats and receives commands
4. Agent claims or works assigned tasks through the API
5. Agent posts progress, artifacts, and completion output
6. Humans review the work in the live dashboard

## API Surface

Apex Claw exposes a Rails JSON API under `/api/v1`.

Key resources:
- `agents`
- `agent_commands`
- `boards`
- `tasks`
- `task_handoffs`
- `task_artifacts`
- `audit_logs`
- `settings`
- `events` (SSE/event stream support)

Useful references:
- `docs/AGENT_INTEGRATION.md`
- `docs/api/OPENAPI_REFERENCE.md`
- `docs/sdk/GO_AGENT_SDK.md`
- `config/routes.rb`

## Deployment

- local development: `docker-compose.yml`
- production-oriented path: bare-metal VPS scripts plus systemd/nginx
- current deployment guide: `DEPLOYMENT.md`

There is no checked-in production Docker stack in this repo yet.

## Documentation Map

If you are orienting yourself quickly, start here:

1. `README.md`
2. `QUICKSTART.md`
3. `docs/ADVANCEMENT_PLAN.md`
4. `docs/AGENT_INTEGRATION.md`
5. `docs/api/OPENAPI_REFERENCE.md`
6. `docs/sdk/GO_AGENT_SDK.md`
7. `docs/fleet/README.md`
8. `docs/fleet/SECURITY.md`

## Contributing

Contributions are welcome.

Basic workflow:

```bash
git checkout -b feature/your-change
bin/ci
git commit -m "feat: describe your change"
```

Please keep PRs focused and update docs when behavior changes.

## Project

- repository: <https://github.com/SweetSophia/clawdeck>
- product name: **Apex Claw**
- status: independently maintained and actively expanded

## License

MIT, see `LICENSE`.
