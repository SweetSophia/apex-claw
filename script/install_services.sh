#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

APP_USER=${APP_USER:-clawdeck}
APP_ROOT=${APP_ROOT:-/var/www/clawdeck}
APP_DOMAIN=${APP_DOMAIN:-apexclaw.local}
APP_DOMAIN_ALIASES=${APP_DOMAIN_ALIASES:-}
APP_PORT=${APP_PORT:-3000}
CERTBOT_EMAIL=${CERTBOT_EMAIL:-}
NGINX_SITE_NAME=${NGINX_SITE_NAME:-apex-claw}

if [[ -z "$CERTBOT_EMAIL" ]]; then
  echo "CERTBOT_EMAIL must be set before running this script." >&2
  exit 1
fi

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  echo "App user '$APP_USER' does not exist. Run script/setup_vps.sh first." >&2
  exit 1
fi

APP_HOME=$(getent passwd "$APP_USER" | cut -d: -f6)
APP_GROUP=$(id -gn "$APP_USER")
SERVER_NAMES="$APP_DOMAIN"
for alias in ${APP_DOMAIN_ALIASES//,/ }; do
  if [[ -n "$alias" && "$alias" != "$APP_DOMAIN" ]]; then
    SERVER_NAMES+=" $alias"
  fi
done

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&|\\]/\\&/g'
}

render_template() {
  local template_path=$1
  local destination_path=$2

  sed \
    -e "s|__APP_USER__|$(escape_sed "$APP_USER")|g" \
    -e "s|__APP_GROUP__|$(escape_sed "$APP_GROUP")|g" \
    -e "s|__APP_HOME__|$(escape_sed "$APP_HOME")|g" \
    -e "s|__APP_ROOT__|$(escape_sed "$APP_ROOT")|g" \
    -e "s|__APP_PORT__|$(escape_sed "$APP_PORT")|g" \
    -e "s|__APP_DOMAIN__|$(escape_sed "$APP_DOMAIN")|g" \
    -e "s|__SERVER_NAMES__|$(escape_sed "$SERVER_NAMES")|g" \
    "$template_path" > "$destination_path"
}

echo "==> Installing Apex Claw services for $APP_DOMAIN"
if [[ -n "$APP_DOMAIN_ALIASES" ]]; then
  echo "==> Additional certificate/server aliases: $APP_DOMAIN_ALIASES"
fi
install -d -o "$APP_USER" -g "$APP_GROUP" /var/log/apex-claw
chown -R "$APP_USER:$APP_GROUP" /var/log/apex-claw
install -d /var/www/certbot

echo "==> Rendering systemd units..."
render_template "$APP_ROOT/config/systemd/puma.service" /etc/systemd/system/puma.service
render_template "$APP_ROOT/config/systemd/solid_queue.service" /etc/systemd/system/solid_queue.service

systemctl daemon-reload
systemctl enable puma solid_queue

echo "==> Installing nginx bootstrap config..."
render_template "$APP_ROOT/config/nginx/clawdeck.conf" "/etc/nginx/sites-available/$NGINX_SITE_NAME"
ln -sf "/etc/nginx/sites-available/$NGINX_SITE_NAME" "/etc/nginx/sites-enabled/$NGINX_SITE_NAME"
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "==> Requesting Let's Encrypt certificates..."
CERTBOT_DOMAINS=("-d" "$APP_DOMAIN")
for alias in ${APP_DOMAIN_ALIASES//,/ }; do
  if [[ -n "$alias" && "$alias" != "$APP_DOMAIN" ]]; then
    CERTBOT_DOMAINS+=("-d" "$alias")
  fi
done

certbot --nginx --redirect --non-interactive --agree-tos --email "$CERTBOT_EMAIL" "${CERTBOT_DOMAINS[@]}"

nginx -t
systemctl restart nginx

echo "==> Services installed successfully."
echo "==> Start the app services with:"
echo "    systemctl start puma solid_queue"
echo "==> Check status with:"
echo "    systemctl status puma solid_queue nginx --no-pager"
