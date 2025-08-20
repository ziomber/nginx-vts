#!/bin/sh
set -e

certbot renew --quiet --deploy-hook "nginx -s reload"
chmod -R go-rwx /etc/letsencrypt

