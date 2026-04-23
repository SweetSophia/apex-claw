# AGENTS.md

This file provides guidance to Claude Code and other AI agents when working with code in this repository.

## Project Overview

Apex Claw is a Rails 8.1 AI agent orchestration platform with a Rails control plane and a Go agent runtime. It combines multi-board task management, agent registration, heartbeats, command delivery, artifacts, handoffs, audit logging, rate limiting, and live dashboard updates.

As of April 23, 2026, all four advancement phases and Sprint A through Sprint E are complete. Ops hardening is merged. The previously final planned backlog item, configurable heartbeat interval, shipped in PR #13 (`3c51cc7`).

## Development Commands

### Initial Setup
```bash
bin/setup              # Install dependencies, prepare database, start server
bin/setup --skip-server  # Setup without starting the server
bin/setup --reset      # Setup with database reset
```

### Running the Application
```bash
bin/dev                # Start development server (web + Tailwind CSS watch)
bin/rails server       # Start web server only
bin/rails tailwindcss:watch  # Watch and rebuild Tailwind CSS
```

### Database
```bash
bin/rails db:prepare   # Create, migrate, and seed database
bin/rails db:migrate   # Run pending migrations
bin/rails db:reset     # Drop, create, migrate, seed
bin/rails db:seed:replant  # Truncate and reseed
```

### Testing
```bash
bin/rails test              # Run all unit/integration tests
bin/rails test:system       # Run system tests (Capybara + Selenium)
bin/rails test test/models/user_test.rb  # Run specific test file
bin/rails test test/models/user_test.rb:10  # Run specific test line
```

### Code Quality and Security
```bash
bin/rubocop            # Run RuboCop linter (Omakase Ruby style)
bin/rubocop -a         # Auto-correct offenses
bin/brakeman           # Security analysis
bin/bundler-audit      # Check for vulnerable gem versions
bin/importmap audit    # Check for vulnerable JavaScript dependencies
bin/ci                 # Run full CI suite (setup, linting, security, tests)
```

### Asset Management
```bash
bin/rails assets:precompile  # Precompile assets for production
bin/importmap pin <package>  # Pin JavaScript package from CDN
bin/importmap unpin <package>  # Unpin JavaScript package
```

### Deployment
```bash
# bootstrap / service installation is performed by a privileged operator
bash script/setup_vps.sh
bash script/install_services.sh

# day-to-day runtime checks
systemctl status puma
systemctl status solid_queue
systemctl restart puma
systemctl restart solid_queue
tail -f /var/log/apex-claw/puma.log
tail -f /var/log/apex-claw/solid_queue.log
```

Production bootstrap now assumes a dedicated app user, default `apexclaw`, rather than root-owned app services. Domain aliases are opt-in via `APP_DOMAIN_ALIASES`. See `DEPLOYMENT.md` for the current env-driven install flow and required environment variables.

## Architecture

### Technology Stack
- **Ruby/Rails**: 4.0.3 / 8.1.x
- **Database**: PostgreSQL with multi-database setup (primary, cache, queue, cable)
- **Background Jobs**: Solid Queue (database-backed)
- **Caching**: Solid Cache (database-backed)
- **WebSockets**: Solid Cable (database-backed)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS, importmap for JavaScript
- **Email**: Resend API (passwordless authentication with 6-digit codes)
- **OAuth**: GitHub authentication support
- **Image Processing**: Active Storage with image_processing gem
- **Deployment**: bare-metal VPS scripts + systemd/nginx, local Docker for development, GitHub Actions for CI/releases
- **Web Server**: Puma with Nginx reverse proxy

### Key Models and Relationships

#### User
- Email-based authentication with optional GitHub OAuth
- `has_many :boards` - User's Kanban boards
- `has_many :tasks` - User's tasks
- `has_many :agents` - User's AI agents
- `has_many :api_tokens` - API authentication tokens
- `has_many :join_tokens` - For collaboration invite links
- Creates onboarding board on signup

#### Board
- Kanban board with columns (inbox, up_next, in_progress, in_review, done)
- `belongs_to :user`
- `has_many :tasks` (dependent: destroy)
- Position-based ordering
- Creates default onboarding board with sample tasks on signup

#### Task
- Individual task items with full lifecycle tracking
- `belongs_to :user`, `belongs_to :board`
- `belongs_to :assigned_agent, class_name: "Agent"` (optional)
- `belongs_to :claimed_by_agent, class_name: "Agent"` (optional)
- `has_many :activities, class_name: "TaskActivity"`
- `has_many :subtasks`
- Status enum: `inbox`, `up_next`, `in_progress`, `in_review`, `done`
- Priority enum: `none`, `low`, `medium`, `high`
- Position-based ordering within status columns
- Tracks `completed_at` and `original_position` for completion/restoration
- Real-time broadcasts via Turbo Streams when changed via API/background jobs

#### Agent
- AI agent identity associated with a user
- `belongs_to :user`
- `has_many :agent_tokens` - API tokens with rotation support
- `has_many :agent_commands` - Queued commands for the agent
- `has_one :agent_rate_limit`
- Status enum: `offline`, `online`, `draining`, `disabled`
- Tracks `hostname`, `platform`, `version`, `last_heartbeat_at`

#### AgentToken
- Rotatable API tokens for agent authentication
- `belongs_to :agent`
- Tracks `last_rotated_at`, `last_used_at`, `expires_at`
- Can be revoked (soft-delete via `revoked_at`)

#### AgentCommand
- Commands queued for agents to execute
- `belongs_to :agent`
- `belongs_to :requested_by_user`
- States: `pending`, `acknowledged`, `completed`, `failed`
- Stores `kind`, `payload` (JSON), `result` (JSON)

#### TaskActivity
- Activity feed for task changes
- Polymorphic `actor` (User or Agent)
- Tracks: `action`, `field_name`, `old_value`, `new_value`, `note`
- Source tracking: `web` or `api`

### Authentication System

#### Web (Cookie-based)
- Session-based authentication using signed cookies
- Passwordless email authentication with 6-digit codes (15-minute expiry)
- GitHub OAuth as alternative login method
- Key concern: `Authentication` module in `app/controllers/concerns/authentication.rb`

#### API (Token-based)
- `Api::TokenAuthentication` concern in `app/controllers/concerns/api/token_authentication.rb`
- Accepts `Authorization: Bearer <token>` header
- Two token types:
  - `ApiToken` - User's primary API token
  - `AgentToken` - Rotatable tokens for agents
- Tracks API usage via `ApiUsageRecord`

#### Agent Identity Headers
Agents should include these headers:
- `X-Agent-Name` - Agent's display name (e.g., "Maxie")
- `X-Agent-Emoji` - Agent's emoji (e.g., "🦊")

### Routes

#### Web Routes
```
/home                     # Dashboard (authenticated)
/boards                   # Boards index
/boards/:id               # Board view (Kanban columns)
/auth/github/callback     # OAuth callback
```

#### API v1 Routes
```
/api/v1/boards            # Board CRUD
/api/v1/tasks             # Task CRUD with query params
/api/v1/tasks/next        # Get next assigned task
/api/v1/tasks/pending_attention  # Tasks needing attention
/api/v1/agents            # Agent management
/api/v1/agent_commands    # Command queue for agents
/api/v1/audit_logs        # Audit log access
/api/v1/events            # SSE events stream
/api/v1/settings          # User settings
```

### CI Pipeline
GitHub Actions runs on PR and push to main:
1. **scan_ruby**: Brakeman (security) + bundler-audit (gem vulnerabilities)
2. **scan_js**: importmap audit (JS vulnerabilities)
3. **lint**: RuboCop style check
4. **test**: Rails unit/integration tests with PostgreSQL service
5. **system-test**: System tests with PostgreSQL service (screenshots on failure)

Local CI command (`bin/ci`) runs:
1. Setup (dependencies + database)
2. RuboCop style check
3. Security audits (bundler-audit, importmap audit, brakeman)
4. Unit/integration tests
5. System tests
6. Database seed test

### Testing Configuration
- Test parallelization enabled (uses all processor cores)
- Fixtures loaded from test/fixtures/*.yml
- Custom test helper: `test/test_helpers/session_test_helper.rb`
- System tests use Capybara + Selenium WebDriver
- GitHub Actions uses PostgreSQL 16 service container

## Agent Integration

### Overview
Apex Claw is designed for human-agent collaboration:
1. Human assigns tasks to agent via UI
2. Agent polls for assigned work via API
3. Agent updates task status and adds activity notes
4. Human reviews before marking done

### Agent Workflow
```
1. Wait for assignment → Poll for tasks with assigned=true
2. Start work → Move to in_progress, add activity note
3. Work on it → Add activity notes for progress
4. Get stuck? → Set blocked=true, add note
5. Finish → Move to in_review, add summary
6. Human reviews → User moves to done (or back for revisions)
```

### Polling Pattern
```
Every 30-60 seconds:
  1. GET /api/v1/tasks?assigned=true&status=up_next
  2. If tasks exist:
       - Claim first task (move to in_progress)
       - Work on it
```

## Frontend Architecture

### Stimulus Controllers
Located in `app/javascript/controllers/`:
- **board_controller.js** - Main board interactions
- **task_board_controller.js** - Task drag-drop
- **task_modal_controller.js** - Task detail panel
- **sortable_controller.js** - Drag-drop ordering
- **dropdown_controller.js** - Reusable dropdown menus
- **flash_controller.js** - Toast notifications
- **delete_confirm_controller.js** - Delete confirmations
- **agent_presence_controller.js** - Agent online status
- **command_bar_controller.js** - ⌘K command palette
- **clipboard_controller.js** - Copy to clipboard
- **datepicker_controller.js** - Due date picker

### Turbo Streams
Used for real-time updates:
- Task CRUD operations return turbo_stream responses
- Task broadcasts to board stream on changes
- Activity feed updates in real-time
- Column counts update on task changes

## UI Design System

Before making UI changes, read:
- `docs/design/DESIGN_SYSTEM.md` - Design tokens, colors, spacing
- `docs/design/UI_MIGRATION.md` - Migration plan from current to design system
- `docs/design/apex-claw-board-v3.jsx` and `apex-claw-home-v4.jsx` - Visual reference (ERB patterns, not React)

Key design tokens:
- Background: `#0c0c0f` (base), `#161619` (board), `#1e1e22` (card)
- Text: `#e0e0e0`
- Accent: Amber/gold (`#fbbf24`)
- Selection: `::selection { background: #fbbf24; color: #161619; }`

## Development Guidelines

## Workflow Reminder

Recall Workflow Rules:
Understand → build the best path (delegated based on Agent rules, split and parallelized as much as possible) → execute → verify.
If delegating, launch the specialist in the same turn you mention it.

### Conventions
- Never default to regular JS if Turbo/Hotwire can accomplish the same thing
- Always follow Rails conventions and use DRY principles
- Use Turbo Streams for real-time UI updates
- Agents communicate via REST API, not WebSockets
- Activity tracking should be declarative (see `Task` callbacks)

### Gotchas
- `Task` broadcasts skip when `activity_source == "web"` (UI handles it)
- `AgentToken` uses `revoked_at` for soft-delete, not hard delete
- `Task.status` drives `Task.completed` via `before_save` callback
- Position is scoped to board+status, not global
- API v1 uses `Api::TokenAuthentication` concern, not web auth

### Deployment
- Project deployed via GitHub Actions by pushing to main branch
- Backup all 4 databases before migrations
- Rollback migration on failure
- Required env vars: `RAILS_MASTER_KEY`, `DATABASE_URL`, `APP_HOST`, `RESEND_API_KEY`
