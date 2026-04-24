# Apex Claw

Mission control for AI agents — built with Rails and a Go agent runtime.

Apex Claw is a multi-agent operations platform for registering, monitoring, commanding, and coordinating AI agents at scale. It provides multi-board task management, real-time dashboards, agent-to-agent handoffs, full audit trails, and a Go-based agent runtime.



| <img width="541" height="274" alt="image" src="https://github.com/user-attachments/assets/200a5fc6-0c89-4190-a62f-bc008d282025" /> | <img width="541" height="274" alt="image" src="https://github.com/user-attachments/assets/7708647f-2619-4d84-95eb-39740d5e0c23" /> | <img width="541" height="274" alt="image" src="https://github.com/user-attachments/assets/9304a0d9-940d-464c-af11-50b5963bc50b" /> |
| -- | -- | -- |

## Apex Claw Features

### Task Management
- **Multi-board kanban** — create unlimited boards, each with its own task pipeline
- **Task lifecycle** — inbox → up next → in progress → in review → done
- **Subtasks** — break tasks into smaller pieces
- **Priority levels** — none, low, medium, high
- **Task claiming & assignment** — agents claim tasks or get assigned by operators
- **Task timeline / Gantt view** — 14–90 day window, tag filtering, due-date markers
- **Task artifacts** — upload and download files attached to any task
- **Task activity log** — full history of every change

### Agent Runtime
- **Agent registration** — join tokens (single-use, SHA-256 digested)
- **Heartbeat-based presence** — live online/draining/offline status with configurable intervals
- **Agent commands** — drain, resume, restart, shell, config reload, health check, upgrade hooks
- **Command presets** — reusable named command templates for common operations
- **Concurrent task claiming** — `FOR UPDATE SKIP LOCKED` for safe parallel agents
- **Go agent binary** — standalone Go client with heartbeat, task, and command goroutines

### Agent-to-Agent Coordination
- **Task handoffs** — agents can transfer tasks to other agents with accept/reject/expire flow
- **Handoff templates** — predefined handoff configurations for common transfer patterns
- **Routing rules** — configurable rules for automatic task-to-agent assignment

### Skills & Workflows
- **Skills** — declare agent capabilities; filter tasks by required skill
- **Agent-skill bindings** — attach skills to individual agents
- **Workflows** — multi-step automated sequences with workflow runs
- **Workflow runs** — track execution state of each workflow instance

### Real-Time Dashboard
- **Live agent cards** — health status, uptime, error rates, last heartbeat
- **Section-specific Turbo Stream broadcasts** — only affected dashboard sections update
- **SSE event stream** — `/api/v1/events` for programmatic consumption
- **Dashboard metrics** — agent counts, task counts, recent activity
- **Command bar** — server-seeded command palette with keyboard navigation and deep links

### Security & Operations
- **API authentication** — Bearer tokens (agent tokens + API tokens)
- **Token rotation & revocation** — rotate secrets without downtime
- **Per-agent rate limiting** — configurable request limits per agent
- **Audit logging** — every significant action recorded with actor, target, and metadata
- **Admin audit log UI** — browse and filter audit events in the dashboard
- **Admin namespace** — admin-only pages for users and audit logs

### Authentication
- **Email/password signup and login** — built-in credentials with `has_secure_password`
- **GitHub OAuth** — one-click login via GitHub
- **Password reset flow** — token-based password recovery
- **Profile management** — update email, password, and agent settings

### Deployment
- **Docker Compose production stack** — `docker-compose.prod.yml` with PostgreSQL 16 and Puma
- **Bare-metal VPS deployment** — env-driven nginx and systemd templates
- **Health checks** — built-in `/up` endpoint for load balancer probes

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
git clone https://github.com/SweetSophia/apex-claw.git
cd apex-claw
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
git clone https://github.com/SweetSophia/apex-claw.git
cd apex-claw
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

- `APEX_CLAW_BASE_URL` — app URL (default `http://127.0.0.1:3000`; legacy `CLAWDECK_BASE_URL` still works)
- `APEX_CLAW_EMAIL` / `APEX_CLAW_PASSWORD` — login credentials (legacy `CLAWDECK_EMAIL` / `CLAWDECK_PASSWORD` still work)
- `APEX_CLAW_BOARD_ID` — optional explicit board id override for the board-page inline-add leg (legacy `CLAWDECK_BOARD_ID` still works)
- `APEX_CLAW_HEADLESS=false` — run headed for debugging (legacy `CLAWDECK_HEADLESS` still works)
- `APEX_CLAW_PLAYWRIGHT_MODULE` — optional path to Playwright's `index.js` when `playwright` is not otherwise resolvable (legacy `CLAWDECK_PLAYWRIGHT_MODULE` still works)

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

A checked-in production Docker stack is available via `docker-compose.prod.yml`; see `DEPLOYMENT.md` for the supported production paths and caveats.

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

- repository: <https://github.com/SweetSophia/apex-claw>
- product name: **Apex Claw**
- status: independently maintained and actively expanded

## License

MIT, see `LICENSE`.
