#!/bin/sh
set -e

NGINX_CONF_DIR=/etc/nginx
NGINX_CONF_FILE=$NGINX_CONF_DIR/nginx.conf
VTS_CONF="${NGINX_CONF_DIR}/conf.d/vts.conf"

if [ -z "$(ls -A $NGINX_CONF_DIR)" ]; then
  echo "[INIT] /etc/nginx is empty, seeding default config..."
  cp -r /usr/share/nginx/nginx/* $NGINX_CONF_DIR/
fi

if ! grep -q "### CUSTOM SETTINGS ###" "$NGINX_CONF_FILE"; then
  echo "[INIT] injecting custom block into nginx.conf..."
  sed -i '1i \
### CUSTOM SETTINGS ###\n\
load_module /etc/nginx/modules/ngx_http_vhost_traffic_status_module.so;\n\
worker_rlimit_nofile 65535;\n\
### END CUSTOM SETTINGS ###\n' "$NGINX_CONF_FILE"
fi

if ! grep -q "vhost_traffic_status_zone;" "$NGINX_CONF_FILE"; then
  echo "[INIT] injecting vhost_traffic_status_zone into http{}..."
  sed -i '/http {/a \    vhost_traffic_status_zone;' "$NGINX_CONF_FILE"
fi

CIDRS=$(ip -4 route | awk '/proto kernel/ && /scope link/ {print $1}')
if [ -z "$CIDRS" ]; then
  IP_CIDR=$(ip -4 -o addr show scope global | awk '{print $4; exit}')
  if [ -n "$IP_CIDR" ] && command -v python3 >/dev/null 2>&1; then
    NET_CIDR=$(python3 - <<'PY'
import os, ipaddress
cidr=os.environ.get("IP_CIDR","")
if cidr:
    print(ipaddress.ip_network(cidr, strict=False))
PY
    )
    CIDRS="$NET_CIDR"
  fi
fi
if [ -z "$CIDRS" ]; then
  echo "[WARN] Do not found any IPv4 network. The /status will be accessible only from 127.0.0.1."
fi
{
  echo "server {"
  echo "  listen 8080;"
  echo "  server_name _;"
  echo ""
  echo "  location /status {"
  echo "    vhost_traffic_status_display;"
  echo "    vhost_traffic_status_display_format html;"
  echo "  }"
  echo ""
  echo "  location /status/format/json {"
  echo "    vhost_traffic_status_display;"
  echo "    vhost_traffic_status_display_format json;"
  echo "  }"
  echo ""
  echo "  allow 127.0.0.1;"
  if [ -n "$CIDRS" ]; then
    for C in $CIDRS; do
      echo "  allow ${C};"
    done
  fi
  echo "  deny all;"
  echo "}"
} > "$VTS_CONF"

echo "[OK] vts.conf regenerated. Allowed networks:"
echo " - 127.0.0.1"
for C in $CIDRS; do echo " - $C"; done

service cron start
exec nginx -g 'daemon off;'
