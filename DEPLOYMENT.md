# Apex Claw Deployment Guide

This repository currently ships three operational paths:

1. **Local Docker development**, which works well for development
2. **Bare-metal VPS deployment scripts**, which are the primary checked-in production-oriented path
3. **Production Docker Compose**, for straightforward single-host internal/Tailscale deployments

There is still **not** an auto-deploy workflow for VPS releases. GitHub Actions cover CI and tagged releases, not server deployment.

## What exists today

Checked into the repo:
- `script/setup_vps.sh` — installs system packages, PostgreSQL, nginx, certbot, a dedicated app user, rbenv, and Ruby
- `script/install_services.sh` — renders systemd/nginx templates, enables services, and provisions TLS with certbot
- `config/systemd/puma.service` — template rendered during install
- `config/systemd/solid_queue.service` — template rendered during install
- `config/nginx/apex-claw.conf` — nginx bootstrap template rendered during install
- `docker-compose.prod.yml` — production Docker Compose for a single-host deployment
- `.env.production.example`

## Important caveats before deploying

The VPS scripts are intentionally opinionated, but they are no longer tied to root-owned app services or a single hardcoded domain.

This guide still contains intentional `clawdeck` repository identifiers such as the current GitHub clone URL. Those values reflect the current repository slug and do not imply that the product name has reverted.

Defaults if you do not override them:
- Ubuntu VPS
- deployment path: `/var/www/apex-claw`
- dedicated runtime user: `apexclaw`
- rbenv installed under `/home/apexclaw/.rbenv`
- PostgreSQL running locally
- nginx terminating TLS
- primary hostname: `apexclaw.local` by default (set your real domain before production use)
- alias hostname: none by default (set `APP_DOMAIN_ALIASES` if you want extras such as `www.example.com`)

You can override the important values with environment variables when running the scripts.

## Recommended production path right now

Use one of these depending on your target:

- **bare-metal + systemd + nginx** for a conventional internet-facing VPS
- **production Docker Compose** for a single host, internal-only, or Tailscale-only deployment

## Production Docker Compose

This repo now includes `docker-compose.prod.yml` for a straightforward production container deployment.

Use it when you want:
- a single host deployment
- no public reverse proxy yet
- internal or Tailscale-only access
- a faster bootstrap than the full nginx/systemd path

### 1. Create the production env file

At minimum:

```bash
cp .env.production.example .env.production
```

Then set real values for at least:

```bash
SECRET_KEY_BASE="$(openssl rand -hex 64)"
APEX_CLAW_DB_PASSWORD='choose-a-strong-password'
CLAWDECK_DB_PASSWORD='choose-a-strong-password'   # legacy fallback; optional during migration
APP_HOST='100.111.85.48:3000'
APP_PROTOCOL='http'
APP_FORCE_SSL='false'
APP_ALLOWED_HOSTS='100.111.85.48,127.0.0.1,::1'
```

Optional overrides depend on your host and desired bindings:
- `DATABASE_URL`
- `APP_HOST`
- `APP_PROTOCOL`
- `APP_FORCE_SSL`
- `APP_ALLOWED_HOSTS`
- custom Docker port bindings in `docker-compose.prod.yml`

### 2. Build and start

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml build
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
```

Notes:
- the production container startup runs `db:create db:migrate && assets:precompile` before booting Rails
- the first boot after a rebuild can take a little longer because Propshaft/Tailwind assets are compiled there
- if you change app code or asset inputs, rebuild the image before restarting

### 3. Verify the app

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml logs -f app
curl -I http://127.0.0.1:3000/up
```

If you expose the app on a Tailscale IP or another bind address, also verify that host directly.

### 4. Create an admin user

Example:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec app bin/rails runner '
user = User.create!(
  email_address: "admin@example.com",
  password: "change-me-now",
  password_confirmation: "change-me-now",
  admin: true
)
Board.create_onboarding_for(user)
puts user.email_address
'
```

### 5. Important caveats

- `docker-compose.prod.yml` is currently aimed at **single-host** deployments, not a full public internet edge stack
- if you are serving plain HTTP internally or over Tailscale, set `APP_PROTOCOL=http` and `APP_FORCE_SSL=false`
- review host allowlists carefully
- if you later place nginx/caddy in front, you may want to tighten binds back to localhost only
- if you rebuild from scratch, remember that Propshaft production assets must exist in `public/assets`; this is why the production startup path runs `assets:precompile`

## Bare-metal VPS deployment

### 1. Provision the server

Recommended baseline:
- Ubuntu 24.04
- 1 GB RAM or more
- DNS pointed at your server
- SSH access as root or a sudo-capable operator

### 2. Set required shell variables

Before running the setup script:

```bash
export DB_PASSWORD='choose-a-strong-password'
export APP_USER='apexclaw'                 # optional override
export APP_ROOT='/var/www/apex-claw'       # optional override
export DATABASE_USER='apexclaw'            # optional override
```

Before running the service installer:

```bash
export APP_DOMAIN='apexclaw.local'
export APP_DOMAIN_ALIASES='www.example.com'   # optional, comma-separated; leave unset for no aliases
export CERTBOT_EMAIL='you@example.com'
export APP_PORT='3000'                     # optional override
```

### 3. Run the server bootstrap

From the repo or by copying the script onto the server:

```bash
bash script/setup_vps.sh
```

What this script does:
- updates packages
- installs PostgreSQL, nginx, certbot, build deps
- creates a dedicated app user if missing
- installs rbenv and Ruby for that app user
- creates the production databases
- prepares the app root and log directories with app-user ownership
- re-owns existing writable runtime directories (`tmp`, `storage`, `log`) for safer upgrades from older root-owned installs

### 4. Clone the repository on the server

Clone as the app user into the app root:

```bash
runuser -u "$APP_USER" -- git clone https://github.com/SweetSophia/clawdeck.git "$APP_ROOT"
cd "$APP_ROOT"
```

If the directory already exists and you are deploying updates, just pull the latest code as the app user.

### 5. Create the production env file

```bash
cp .env.production.example .env.production
```

Fill in real values for at least:
- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`
- `APEX_CLAW_DB_PASSWORD` (preferred) or `DATABASE_URL`
- `APP_HOST`
- `APP_ALLOWED_HOSTS`
- `MAILER_FROM`
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET` if using GitHub OAuth

If you want separate databases for queue/cache/cable on a VPS, also set:
- `CACHE_DATABASE_URL`
- `QUEUE_DATABASE_URL`
- `CABLE_DATABASE_URL`

If you leave those unset, Rails falls back to `DATABASE_URL`.

### 6. Install gems and prepare the app

Run app setup as the dedicated app user:

```bash
runuser -u "$APP_USER" -- bash -lc '
  export RBENV_ROOT="$HOME/.rbenv"
  export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
  eval "$(rbenv init - bash)"
  cd "$APP_ROOT"
  bundle install --deployment --without development test
  RAILS_ENV=production bundle exec rails db:prepare
  RAILS_ENV=production bundle exec rails assets:precompile
'
```

### 7. Install systemd services and nginx config

```bash
bash script/install_services.sh
```

This step:
- renders the systemd unit templates with `APP_USER`, `APP_ROOT`, and the app-user home directory
- renders the nginx bootstrap config with your domain names and app port
- enables `puma`, `solid_queue`, and `nginx`
- runs certbot with `--nginx --redirect` to provision TLS and rewrite the nginx site in place

### 8. Start and verify services

```bash
systemctl start puma solid_queue
systemctl status puma solid_queue nginx --no-pager
curl -I http://127.0.0.1:3000/up
```

## Operational notes

### Runtime user model

The checked-in production units now run as a **dedicated app user**, not as `root`.

That gives you a safer default:
- app code owned by the app user
- rbenv isolated under the app user's home directory
- systemd services execute with reduced privilege
- certbot/nginx setup still happens from a root-operated install step

### Host and mailer config

Production host configuration is env-driven:
- `APP_HOST` — canonical app host used by Rails and mailers
- `APP_PROTOCOL` — default `https`
- `APP_ALLOWED_HOSTS` — comma-separated host allowlist for Rails host authorization
- `MAILER_FROM` — Action Mailer sender address

Set `APP_HOST` explicitly in production. External URL helpers now avoid deriving
canonical URLs from the inbound request host when `APP_HOST` is unset, so deploy
configuration remains the source of truth for generated links. If a production
deployment should generate `http` URLs (for example, internal or Tailscale-only
access), also set `APP_PROTOCOL=http`; otherwise the production fallback remains
`https`.

### Database wiring

Production supports both:
- **single-URL deploys** via `DATABASE_URL`
- **split database deploys** via `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, and `CABLE_DATABASE_URL`

That keeps the checked-in VPS bootstrap aligned with Rails production config.

## GitHub Actions status

Current workflows:
- `.github/workflows/ci.yml` — lint, security scans, Rails tests, system tests
- `.github/workflows/release.yml` — tagged GitHub release creation

There is currently no repo-managed VPS deploy workflow.

## Development Docker vs production

- `docker-compose.yml` is the local development stack
- `docker-compose.prod.yml` is the single-host production container stack
- the bare-metal scripts remain the more complete path when you want nginx, certbot, and systemd-managed services

## Troubleshooting

### App fails after gem changes in Docker

```bash
docker compose run --rm app bundle install
docker compose up -d app
```

### Production layout is broken or styles are missing

This usually means production assets were not precompiled.

Rebuild and restart the production stack so startup can regenerate the asset manifest:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml build
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
```

If needed, manually precompile once inside the running container:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec app bin/rails assets:precompile
docker compose --env-file .env.production -f docker-compose.prod.yml restart app
```

### Check Puma logs

```bash
tail -f /var/log/apex-claw/puma.log
tail -f /var/log/apex-claw/puma_error.log
```

### Check Solid Queue logs

```bash
tail -f /var/log/apex-claw/solid_queue.log
tail -f /var/log/apex-claw/solid_queue_error.log
```

### Check nginx config

```bash
nginx -t
systemctl status nginx --no-pager
```

### Check Rails health endpoint

```bash
curl -I http://127.0.0.1:3000/up
```
