ARG NGINX_VERSION=1.29.3
ARG NGINX_CODE=trixie

FROM debian:bookworm-slim AS builder
ARG NGINX_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git build-essential \
    libpcre3-dev zlib1g-dev libssl-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN curl -fsSLO http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar xzf nginx-${NGINX_VERSION}.tar.gz
RUN git clone --depth=1 https://github.com/vozlt/nginx-module-vts.git

WORKDIR /tmp/nginx-${NGINX_VERSION}
RUN ./configure \
      --with-compat \
      --with-http_ssl_module \
      --with-http_stub_status_module \
      --add-dynamic-module=/tmp/nginx-module-vts \
 && make modules

FROM nginx:${NGINX_VERSION}-${NGINX_CODE}
ARG NGINX_VERSION

RUN apt-get update \
	&& apt-get full-upgrade -y \
	&& apt-get install -y --no-install-recommends python3 certbot python3-certbot-nginx cron iproute2 logrotate \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/nginx-${NGINX_VERSION}/objs/ngx_http_vhost_traffic_status_module.so /etc/nginx/modules/
RUN cp -r /etc/nginx /usr/share/nginx

VOLUME ["/etc/nginx", "/var/log/nginx", "/etc/letsencrypt"]

########################
# logrotate dla nginx
########################

COPY logrotate-nginx.conf /etc/logrotate.d/nginx

########################
# certbot cron
########################

COPY scripts/renew.sh /usr/local/bin/renew.sh
RUN chmod +x /usr/local/bin/renew.sh \
 && printf 'SHELL=/bin/sh\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n' > /etc/cron.d/certbot \
 && printf '0 3,15 * * * root /usr/local/bin/renew.sh >/var/log/nginx/certbot-renew.log 2>&1\n' >> /etc/cron.d/certbot \
 && chmod 0644 /etc/cron.d/certbot

COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
