FROM owasp/modsecurity-crs:3.3-nginx

LABEL maintainer="https://github.com/Rp70/docker-nginx"

ADD /files/ /

RUN set -x && \
    chmod +x /docker-entrypoint.sh /usr/bin/docker-overwrite /usr/bin/docker-nginx-reload

RUN apt-get update
RUN set -ex && \
    apt-get install -y wget

ENV ACMESH_VERSION 2.8.5
RUN set -x && \
    mkdir -p /tmp/src/acmesh && \
    wget -q -O - https://github.com/acmesh-official/acme.sh/archive/${ACMESH_VERSION}.tar.gz | tar -zx --strip=1 -C /tmp/src/acmesh && \
    mkdir -p /var/www/le_root/.well-known/acme-challenge && \
    chown -R root:www-data /var/www/le_root
    
RUN apt-get install -y supervisor cron

RUN set -x && \
    apt-get auto-remove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/**

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["startup"]
