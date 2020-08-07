FROM owasp/modsecurity-crs:3.3-nginx

LABEL maintainer="https://github.com/Rp70/docker-nginx"

ADD /files/ /

RUN set -x && \
    chmod +x /docker-entrypoint.sh /usr/bin/docker-overwrite /usr/bin/docker-nginx-reload

ENV ACMESH_VERSION 2.8.5
RUN set -x && \
    mkdir -p /tmp/src/acmesh && \
    wget -q -O - https://github.com/acmesh-official/acme.sh/archive/${ACMESH_VERSION}.tar.gz | tar -zx --strip=1 -C /tmp/src/acmesh && \
    mkdir -p /var/www/le_root/.well-known/acme-challenge && \
    chown -R root:www-data /var/www/le_root
    
RUN set -x && \
    apt-get update && \
    apt-get install -y supervisor cron && \
    apt-get auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/**

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["startup"]
