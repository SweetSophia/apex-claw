# ClawDeck Deployment Guide

This repository currently ships two operational paths:

1. **Local Docker development**, which works well for development
2. **Bare-metal VPS deployment scripts**, which are the checked-in production-oriented path

There is **not** a production Docker stack in this repository yet, and there is **not** an auto-deploy workflow for VPS releases. GitHub Actions cover CI and tagged releases, not server deployment.

## What exists today

Checked into the repo:
- `script/setup_vps.sh` — installs system packages, PostgreSQL, nginx, certbot, a dedicated app user, rbenv, and Ruby
- `script/install_services.sh` — renders systemd/nginx templates, enables services, and provisions TLS with certbot
- `config/systemd/puma.service` — template rendered during install
- `config/systemd/solid_queue.service` — template rendered during install
- `config/nginx/clawdeck.conf` — nginx bootstrap template rendered during install
- `.env.production.example`

## Important caveats before deploying

The VPS scripts are intentionally opinionated, but they are no longer tied to root-owned app services or a single hardcoded domain.

Defaults if you do not override them:
- Ubuntu VPS
- deployment path: `/var/www/clawdeck`
- dedicated runtime user: `clawdeck`
- rbenv installed under `/home/clawdeck/.rbenv`
- PostgreSQL running locally
- nginx terminating TLS
- primary hostname: `clawdeck.io`
- alias hostname: none by default (set `APP_DOMAIN_ALIASES` if you want extras such as `www.clawdeck.io`)

You can override the important values with environment variables when running the scripts.

## Recommended production path right now

Use the included **bare-metal + systemd + nginx** deployment flow, but treat it as infra bootstrap, not one-click magic.

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
export APP_USER='clawdeck'                 # optional override
export APP_ROOT='/var/www/clawdeck'        # optional override
export DATABASE_USER='clawdeck'            # optional override
```

Before running the service installer:

```bash
export APP_DOMAIN='clawdeck.io'
export APP_DOMAIN_ALIASES='www.clawdeck.io'   # optional, comma-separated; leave unset for no aliases
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
- `DATABASE_URL`
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

`docker-compose.yml` in this repo is a development stack. It is useful for local work, but it is not yet a production deployment specification.

## Troubleshooting

### App fails after gem changes in Docker

```bash
docker compose run --rm app bundle install
docker compose up -d app
```

### Check Puma logs

```bash
tail -f /var/log/clawdeck/puma.log
tail -f /var/log/clawdeck/puma_error.log
```

### Check Solid Queue logs

```bash
tail -f /var/log/clawdeck/solid_queue.log
tail -f /var/log/clawdeck/solid_queue_error.log
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
