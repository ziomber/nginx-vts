# ziomber/nginx-vts

A Docker image for Nginx with the VTS (vhost traffic status) module (from https://github.com/vozlt/nginx-module-vts) and Certbot integrated for obtaining Let's Encrypt certificates.

This repository contains the Docker build and helper scripts to run Nginx with VTS metrics and to obtain/renew TLS certificates using Certbot. Use it as a drop-in web/proxy image with built-in traffic metrics.

Features
- Nginx compiled with the nginx-module-vts (VTS) for real-time vhost/upstream metrics
- Certbot included so you can obtain and renew Let's Encrypt certificates from within the container
- Suitable volumes and configuration to persist certificates and logs
- Example nginx config snippets for enabling the VTS dashboard and using TLS

Quick start

Build locally
- docker build -t ziomber/nginx-vts:latest .

Run (basic)
- docker run -d \
  -p 80:80 -p 443:443 \
  -v /path/to/nginx/conf:/etc/nginx/conf.d:ro \
  -v /path/to/certs:/etc/letsencrypt \
  -v /path/to/www:/var/www/certbot \
  --name nginx-vts \
  ziomber/nginx-vts:latest

Notes:
- Persist /etc/letsencrypt to keep certificates across restarts.
- Persist /var/www/certbot (or whatever webroot you choose) if you use webroot verification.
- Expose ports 80 and 443 on the host so Certbot can perform HTTP challenges.

Obtaining certificates with Certbot (examples)

Webroot method (recommended when running behind the same container)
- docker exec -it nginx-vts certbot certonly --webroot -w /var/www/certbot -d example.com -d www.example.com --email you@example.com --agree-tos

Standalone method (stop Nginx first or use a temporary container)
- docker exec -it nginx-vts certbot certonly --standalone -d example.com --email you@example.com --agree-tos

Automated renewal
- Certbot supports `renew`. Example:
  - docker exec -it nginx-vts certbot renew --quiet
- You can schedule renewal from the host (cron/systemd) or add a small supervisor script in the container to run renew periodically. Make sure the container has access to the same ports/paths required for verification.

Enabling the VTS dashboard in Nginx

Add a server block or a location to an existing vhost to expose VTS. Example snippet to include in your nginx configuration:

server {
    listen 80;
    server_name vts.example.com;

    # Location for VTS HTML dashboard
    location /vts {
        vhost_traffic_status_display;
        vhost_traffic_status_display_format html;
    }

    # Optional JSON output
    location /status {
        vhost_traffic_status_display;
        vhost_traffic_status_display_format json;
    }
}

Make sure the VTS module is enabled in the build (this image includes it). You may want to restrict access to the VTS endpoints with allow/deny or basic auth for production.

Example Docker Compose

services:
  nginx:
    image: ziomber/nginx-vts:latest
    container_name: nginx-vts
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./letsencrypt:/etc/letsencrypt
      - ./www:/var/www/certbot
    restart: unless-stopped

Configuration tips
- Keep your Nginx configuration in /etc/nginx/conf.d (or modify the image accordingly).
- Create a dedicated vhost for the VTS dashboard and protect it.
- Use a persistent volume for /etc/letsencrypt to preserve certificates.
- If you use DNS validation for wildcards, run Certbot externally or add DNS provider credentials to the container carefully (avoid committing secrets).

Healthchecks
- Add a simple HTTP healthcheck that queries a low-overhead location (e.g., /health) returning 200 from Nginx.

Contributing
- Add issues or PRs with clear descriptions if you want features, fixes, or configuration improvements.
- If you change build options (modules, OpenSSL, etc.), include notes in the Dockerfile and README.

Security
- Protect the VTS dashboard and any management endpoints.
- Keep Certbot and system packages up to date.
- Do not commit private keys or ACME account secrets into the repository.

More
- VTS module: https://github.com/vozlt/nginx-module-vts
- Certbot: https://certbot.eff.org/
