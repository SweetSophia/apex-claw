# ClawDeck Quick Start

Fastest path to a running local ClawDeck instance.

## Recommended: Docker development

This is the lowest-friction setup right now.

```bash
git clone https://github.com/SweetSophia/clawdeck.git
cd clawdeck
docker compose up --build
```

Open <http://localhost:3000>.

Services started by `docker compose`:
- Rails app on `localhost:3000`
- PostgreSQL 16 on `localhost:5432`

### Common Docker recovery

If the app container fails after gem changes or image rebuilds, the persistent `bundle_cache` volume may be stale.
Refresh it with:

```bash
docker compose run --rm app bundle install
docker compose up -d app
```

Useful commands:

```bash
# start in background
docker compose up -d

# view logs
docker compose logs -f app

# run Rails tests
docker compose exec app bin/rails test

# run the full CI-style check set
docker compose run --rm app bin/ci

# stop everything
docker compose down
```

## Native development

Native setup is available, but Docker is currently the smoother path.

Runtime version:
- `.ruby-version` specifies Ruby `4.0.3`
- Docker uses the published `ruby:4.0-slim` image while the app/runtime target is Ruby `4.0.3`

Requirements:
- Ruby `4.0.3`
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

## Test commands

Core checks used in the repo:

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

If your host does not have the full Ruby/Bundler toolchain available, run these via Docker instead.

## Production Docker note

If you run the production Docker stack, Propshaft assets must be precompiled. The checked-in production compose does that on container startup. Use:

```bash
cp .env.production.example .env.production
# then set at least SECRET_KEY_BASE and CLAWDECK_DB_PASSWORD in .env.production

docker compose --env-file .env.production -f docker-compose.prod.yml build
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
```

If the production UI comes up unstyled, rebuild and restart the stack or run:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec app bin/rails assets:precompile
docker compose --env-file .env.production -f docker-compose.prod.yml restart app
```

## Where to go next

- project overview: `README.md`
- roadmap and implementation history: `docs/ADVANCEMENT_PLAN.md`
- API / agent integration: `docs/AGENT_INTEGRATION.md`
- deployment details: `DEPLOYMENT.md`
- fleet architecture notes: `docs/fleet/README.md`
