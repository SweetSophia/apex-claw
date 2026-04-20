# AGENTS.md

This file provides guidance to Claude Code and other AI agents when working with code in this repository.

## Project Overview

ClawDeck is a Rails 8.1 Kanban-style task management application with built-in AI agent integration. It serves as "personal mission control for your AI agent" - a visual interface where humans assign tasks and agents work on them via the REST API.

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
ssh root@YOUR_SERVER_IP  # SSH to production VPS for bootstrap/service management
systemctl status puma         # Check Puma status
systemctl status solid_queue  # Check Solid Queue status
systemctl restart puma        # Restart web server
systemctl restart solid_queue # Restart background jobs
tail -f /var/log/clawdeck/puma.log  # View application logs
tail -f /var/log/clawdeck/solid_queue.log  # View job logs
```

Production bootstrap now assumes a dedicated app user, default `clawdeck`, rather than root-owned app services. See `DEPLOYMENT.md` for the current env-driven install flow.

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
```
