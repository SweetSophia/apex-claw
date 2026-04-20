# ClawDeck

Mission control for AI agents, built with Rails and a Go agent runtime.

This repository is **SweetSophia/clawdeck**, an independently maintained AI agent orchestration platform with agent registration, heartbeats, command delivery, task artifacts, handoffs, audit logs, rate limiting, and real-time updates.

## Current Status

ClawDeck is under active development.

Currently implemented in this codebase:
- multi-board kanban task management
- agent registration with join tokens
- heartbeat-based agent presence and metadata
- agent commands: drain, resume, restart, shell, config reload, health check, upgrade hooks
- task claiming and assignment flows
- task artifacts upload/download
- agent-to-agent task handoff flow
- token rotation and revocation
- per-agent API rate limiting
- audit logging
- Turbo Streams + SSE real-time updates
- dashboard health metrics for agents

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
- `docs/AGENT_INTEGRATION.md` — agent integration guide
- `docs/api/OPENAPI_REFERENCE.md` — current API reference
- `docs/sdk/GO_AGENT_SDK.md` — Go client / SDK guide
- `docs/ADVANCEMENT_PLAN.md` — current roadmap and delivery phases
- `script/loadtest/agent_concurrency_smoke.rb` — concurrent-agent smoke load test
- `docker-compose.yml` — local development stack

## Quick Start

### Option A: Docker development

This is the easiest way to run the app locally.

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
- if gems drift after dependency changes, run:

```bash
docker compose run --rm app bundle install
docker compose up -d app
```

### Option B: Native development

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

If you prefer manual setup:

```bash
bundle install
bin/rails db:prepare
bin/dev
```

## Running Tests

Main test commands used by CI:

```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
```

Docker-based test example:

```bash
docker compose exec app bin/rails test
```

### Playwright smoke test

A lightweight browser smoke check for the command bar lives at `script/playwright/command_bar_smoke.mjs`.

```bash
node script/playwright/command_bar_smoke.mjs
```

Environment variables:

- `CLAWDECK_BASE_URL` — app URL (default `http://127.0.0.1:3000`)
- `CLAWDECK_EMAIL` / `CLAWDECK_PASSWORD` — login credentials (defaults target local fixture-style dev users)
- `CLAWDECK_BOARD_ID` — optional explicit board id override
- `CLAWDECK_HEADLESS=false` — run headed for debugging
- `CLAWDECK_PLAYWRIGHT_MODULE` — path to Playwright's `index.js` if not using the local default

## Core Product Flow

1. Create boards and tasks in the Rails UI
2. Register an agent using a join token
3. Agent sends heartbeats and receives commands
4. Agent claims or works assigned tasks through the API
5. Agent posts progress, artifacts, and completion output
6. Humans review the work in the live dashboard

## API Surface

ClawDeck exposes a Rails JSON API under `/api/v1`.

Key resources:
- `agents`
- `agent_commands`
- `boards`
- `tasks`
- `task_handoffs`
- `task artifacts`
- `audit_logs`
- `settings`
- `events` (SSE/event stream support)

Useful references:
- `docs/AGENT_INTEGRATION.md`
- `docs/api/OPENAPI_REFERENCE.md`
- `docs/sdk/GO_AGENT_SDK.md`
- `config/routes.rb`

## Agent Platform Features

ClawDeck includes substantial agent-platform capabilities across the Rails control plane and Go runtime:

- pluggable Go executor framework
- retry and backoff support
- structured logging
- graceful draining and shutdown behavior
- richer heartbeat metadata including uptime and runner state
- token lifecycle management
- task artifacts
- task handoffs between agents
- stronger API hardening and security review fixes
- richer dashboard health metrics

## Development Notes

- default local app port: `3000`
- default local postgres port: `5432`
- Docker development uses `postgres://postgres:postgres@db:5432/clawdeck_development`
- CI uses PostgreSQL 16 and runs Rails tests directly

## Contributing

Contributions are welcome.

Basic workflow:

```bash
git checkout -b feature/your-change
bin/rails test
bin/rubocop
git commit -m "feat: describe your change"
```

Please keep PRs focused and update docs when behavior changes.

## Project

- repository: <https://github.com/SweetSophia/clawdeck>
- status: independently maintained and actively expanded

## License

MIT, see `LICENSE`.
