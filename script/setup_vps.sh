#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

APP_USER=${APP_USER:-clawdeck}
APP_ROOT=${APP_ROOT:-/var/www/clawdeck}
RUBY_VERSION=${RUBY_VERSION:-4.0.3}
DATABASE_USER=${DATABASE_USER:-clawdeck}
: "${DB_PASSWORD:?DB_PASSWORD must be set before running this script}"

if [[ ! ${APP_USER} =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "APP_USER must be a safe unix username." >&2
  exit 1
fi

if [[ ! ${DATABASE_USER} =~ ^[a-z_][a-z0-9_]*$ ]]; then
  echo "DATABASE_USER must contain only lowercase letters, numbers, and underscores." >&2
  exit 1
fi

echo "==> ClawDeck VPS Setup Script"
echo "==> Installing Ruby, PostgreSQL, nginx, and a dedicated app runtime user"

echo "==> Updating system packages..."
apt-get update
apt-get upgrade -y

echo "==> Installing dependencies..."
apt-get install -y curl git build-essential libssl-dev libyaml-dev libreadline-dev \
  zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev libpq-dev nginx certbot \
  python3-certbot-nginx postgresql postgresql-contrib

echo "==> Ensuring PostgreSQL is running..."
systemctl enable --now postgresql

echo "==> Ensuring app user exists..."
if ! id -u "$APP_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$APP_USER"
fi

APP_HOME=$(getent passwd "$APP_USER" | cut -d: -f6)
APP_GROUP=$(id -gn "$APP_USER")
RBENV_ROOT="$APP_HOME/.rbenv"

echo "==> Installing rbenv and Ruby ${RUBY_VERSION} for ${APP_USER}..."
runuser -u "$APP_USER" -- bash <<EOF
set -euo pipefail
export HOME="$APP_HOME"
if [ ! -d "$RBENV_ROOT" ]; then
  git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
  git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
fi
export RBENV_ROOT="$RBENV_ROOT"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "\$(rbenv init - bash)"
rbenv install -s "$RUBY_VERSION"
rbenv global "$RUBY_VERSION"
gem install bundler --no-document
EOF

echo "==> Creating deployment directories..."
install -d -o "$APP_USER" -g "$APP_GROUP" "$APP_ROOT"
install -d -o "$APP_USER" -g "$APP_GROUP" /var/log/clawdeck
install -d -o "$APP_USER" -g "$APP_GROUP" "$APP_ROOT/shared"

if [[ -d "$APP_ROOT" ]]; then
  for writable_path in tmp storage log; do
    if [[ -e "$APP_ROOT/$writable_path" ]]; then
      chown -R "$APP_USER:$APP_GROUP" "$APP_ROOT/$writable_path"
    fi
  done
fi

echo "==> Configuring PostgreSQL..."
DB_PASSWORD_SQL=${DB_PASSWORD//\'/\'\'}
runuser -u postgres -- psql <<SQL
DO \
\$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${DATABASE_USER}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${DATABASE_USER}', '${DB_PASSWORD_SQL}');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${DATABASE_USER}', '${DB_PASSWORD_SQL}');
  END IF;
END
\$\$;
ALTER ROLE ${DATABASE_USER} CREATEDB;
SQL

for database_name in \
  clawdeck_production \
  clawdeck_cache_production \
  clawdeck_queue_production \
  clawdeck_cable_production
  do
    if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname='${database_name}'" | grep -q 1; then
      runuser -u postgres -- createdb -O "$DATABASE_USER" "$database_name"
    fi
  done

echo "==> Optimizing PostgreSQL for a small VPS..."
PG_CONF=$(runuser -u postgres -- psql -t -P format=unaligned -c 'SHOW config_file;')
if ! grep -q "# ClawDeck low-memory tuning" "$PG_CONF"; then
  cat >> "$PG_CONF" <<'EOF'

# ClawDeck low-memory tuning
shared_buffers = 128MB
effective_cache_size = 256MB
maintenance_work_mem = 32MB
work_mem = 4MB
max_connections = 20
EOF
fi

systemctl restart postgresql

echo "==> VPS setup complete!"
echo "==> App user: $APP_USER"
echo "==> App root: $APP_ROOT"
echo "==> Ruby root: $RBENV_ROOT"
echo "==> Next steps:"
echo "    1. Clone the repository into $APP_ROOT as $APP_USER"
echo "    2. Create $APP_ROOT/.env.production with DATABASE_URL / *_DATABASE_URL values"
echo "    3. Set APP_HOST, APP_ALLOWED_HOSTS, and MAILER_FROM in .env.production"
echo "    4. Run APP_USER=$APP_USER APP_ROOT=$APP_ROOT APP_DOMAIN=your-domain.example CERTBOT_EMAIL=you@example.com bash script/install_services.sh"
