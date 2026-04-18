# ClawDeck Deployment Guide

This repository currently ships two different operational stories:

1. **Local Docker development**, which works well for development
2. **Bare-metal VPS deployment scripts**, which are the only production-oriented path currently checked into the repo

There is **not** a ready-made production Docker stack in this repository yet, and there is **not** an auto-deploy workflow for VPS releases. The included GitHub Actions cover CI and tagged GitHub releases, not server deployment.

## What exists today

Checked into the repo:
- `script/setup_vps.sh` — installs system packages, PostgreSQL, rbenv, Ruby, and initial DBs
- `script/install_services.sh` — installs systemd services and nginx config
- `config/systemd/puma.service`
- `config/systemd/solid_queue.service`
- `config/nginx/clawdeck.conf`
- `.env.production.example`

## Important caveats before deploying

The current VPS scripts are usable, but opinionated. Review them before production use.

They currently assume:
- Ubuntu VPS
- deployment path: `/var/www/clawdeck`
- `root`-owned services
- rbenv installed under `/root/.rbenv`
- PostgreSQL running locally
- nginx terminating TLS
- hostname/domain values hardcoded to `clawdeck.so` and `www.clawdeck.so`

You will almost certainly want to adjust at least:
- `config/nginx/clawdeck.conf`
- `script/install_services.sh`
- `.env.production`
- TLS email/domain values for certbot

## Recommended production path right now

Use the included **bare-metal + systemd + nginx** deployment flow, but treat the scripts as a starting point, not a one-click generic installer.

## Bare-metal VPS deployment

### 1. Provision the server

Recommended baseline:
- Ubuntu 24.04
- 1 GB RAM or more
- DNS pointed at your server
- SSH access as root or sudo-capable operator

### 2. Set required shell variables

Before running the setup script:

```bash
export DB_PASSWORD='choose-a-strong-password'
export CERTBOT_EMAIL='you@example.com'
```

### 3. Run the server bootstrap

From the repo or by copying the script onto the server:

```bash
bash script/setup_vps.sh
```

What this script does:
- updates packages
- installs PostgreSQL, nginx, certbot, build deps
- installs rbenv and Ruby
- creates the production databases
- prepares `/var/www/clawdeck`

### 4. Clone the repository on the server

```bash
cd /var/www
git clone https://github.com/SweetSophia/clawdeck.git
cd clawdeck
```

### 5. Create production env file

```bash
cp .env.production.example .env.production
```

Fill in real values for at least:
- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`
- `DATABASE_PASSWORD`
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET` if using GitHub OAuth

Current example file also exposes these knobs:
- `RAILS_MAX_THREADS`
- `WEB_CONCURRENCY`
- `PORT`
- `DATABASE_HOST`
- `DATABASE_PORT`
- `DB_POOL`

### 6. Install gems and prepare the app

The current service files expect Bundler from rbenv under `/root/.rbenv`.

```bash
export PATH="/root/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
bundle install --deployment --without development test
RAILS_ENV=production bundle exec rails db:prepare
RAILS_ENV=production bundle exec rails assets:precompile
```

### 7. Review domain-specific config before enabling nginx

Before installing services, edit these files if you are not deploying to `clawdeck.so`:
- `config/nginx/clawdeck.conf`
- `script/install_services.sh`

Things to update:
- server names
- certbot domains
- contact email defaults
- any path assumptions specific to your host

### 8. Install systemd services and nginx config

```bash
bash script/install_services.sh
```

This installs:
- `puma.service`
- `solid_queue.service`
- nginx site config
- certbot-managed TLS for the configured domains

### 9. Start and verify services

```bash
systemctl start puma solid_queue nginx
systemctl status puma solid_queue nginx --no-pager
curl -I http://127.0.0.1:3000/up
```

## Operational notes

Current checked-in production units run as `root`:
- `config/systemd/puma.service`
- `config/systemd/solid_queue.service`

That works with the shipped scripts, but it is not the only valid approach. If you want a dedicated deploy user, you will need to adjust the unit files and filesystem ownership.

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
