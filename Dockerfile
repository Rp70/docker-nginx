FROM alpine:3.11

LABEL maintainer="https://github.com/Rp70"

ENV NGINX_VERSION 1.16.1
ENV NJS_VERSION   0.3.8
ENV RTMP_VERSION 1.2.7
ENV PKG_RELEASE   1

ADD /files/ /

RUN set -x && \
    chmod +x /docker-entrypoint.sh

# Reference: https://github.com/docker-library/php/blob/4b7da48c965c32148d028919e224d19cb14898db/7.4/alpine3.11/fpm/Dockerfile
# ensure www-data user exists
RUN set -eux; \
	addgroup -g 82 -S www-data; \
	adduser -u 82 -D -S -H -h /var/cache/nginx -s /sbin/nologin -g nginx -G www-data www-data
# 82 is the standard uid/gid for "www-data" in Alpine
# https://git.alpinelinux.org/aports/tree/main/apache2/apache2.pre-install?h=3.9-stable
# https://git.alpinelinux.org/aports/tree/main/lighttpd/lighttpd.pre-install?h=3.9-stable
# https://git.alpinelinux.org/aports/tree/main/nginx/nginx.pre-install?h=3.9-stable

RUN set -x \
    apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${PKG_RELEASE} \
    " \
    && \
    apk --update add linux-headers openssl-dev pcre-dev zlib-dev wget build-base gnupg ffmpeg

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    # Import GPG public keys at https://nginx.org/en/pgp_keys.html
    wget https://nginx.org/keys/mdounin.key && \
    wget https://nginx.org/keys/maxim.key && \
    wget https://nginx.org/keys/sb.key && \
    gpg --import *.key && \
    echo -e "5\ny\nquit" > keystrokes.txt && \
    gpg2 --no-tty --command-file=keystrokes.txt --edit-key 9C5E7FA2F54977D4 trust && \
    gpg2 --no-tty --command-file=keystrokes.txt --edit-key 520A9993A1C052F8 trust && \
    gpg2 --no-tty --command-file=keystrokes.txt --edit-key A64FD5B17ADB39A8 trust

RUN set -x && \
    cd /tmp/src && \
    # Download source & check sum.
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc && \
    gpg --verify nginx-${NGINX_VERSION}.tar.gz.asc && \
    tar -zxf nginx-${NGINX_VERSION}.tar.gz

RUN set -x && \
    mkdir /tmp/src/rtmp && \
    wget -q -O - https://github.com/winshining/nginx-http-flv-module/archive/v${RTMP_VERSION}.tar.gz | tar -zx --strip=1 -C /tmp/src/rtmp

RUN set -x && \
    apk --update add git libtool autoconf automake make gcc && \
    apk --update add bison && \
    cd /tmp/src && \
    git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity modsecurity && \
    cd modsecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && ./configure && \
    make && make install && \
    cd .. && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git modsecurity-nginx && \
    exit 0


ENV ACMESH_VERSION 2.8.5
RUN set -x && \
    mkdir /tmp/src/acmesh && \
    wget -q -O - https://github.com/acmesh-official/acme.sh/archive/${ACMESH_VERSION}.tar.gz | tar -zx --strip=1 -C /tmp/src/acmesh && \
    mkdir -p /var/www/le_root/.well-known/acme-challenge && \
    chown -R root:www-data /var/www/le_root && \
    exit 0


# ENV PAGESPEED_VERSION 1.13.35.2-stable
# RUN set -x && \
#     mkdir /tmp/src/pagespeed && \
#     wget -q -O - https://github.com/apache/incubator-pagespeed-ngx/archive/v${PAGESPEED_VERSION}.tar.gz | tar -zx --strip=1 -C /tmp/src/pagespeed && \
#     exit 0


RUN set -x && \
    cd /tmp/src/nginx-${NGINX_VERSION} && \
    ./configure \
        --user=nginx \
        --group=nginx \
        --with-compat \
#        --add-module=/tmp/src/pagespeed \
        --add-module=/tmp/src/rtmp \
        --add-module=/tmp/src/modsecurity-nginx \
        --with-file-aio \
        --with-threads \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_gzip_static_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --prefix=/etc/nginx \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx \
        #--with-cc-opt='-g -O2  -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC -Wimplicit-fallthrough=0' \
        #--with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
         && \
    make && \
    make install && \
    apk del build-base && \
    rm -rf /tmp/src && \
    rm -rf /var/cache/apk/* \
    \
#     && case "$apkArch" in \
#         x86_64) \
# # arches officially built by upstream
#             set -x \
#             && KEY_SHA512="e7fa8303923d9b95db37a77ad46c68fd4755ff935d0a534d26eba83de193c76166c68bfe7f65471bf8881004ef4aa6df3e34689c305662750c0172fca5d8552a *stdin" \
#             && apk add --no-cache --virtual .cert-deps \
#                 openssl \
#             && wget -O /tmp/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub \
#             && if [ "$(openssl rsa -pubin -in /tmp/nginx_signing.rsa.pub -text -noout | openssl sha512 -r)" = "$KEY_SHA512" ]; then \
#                 echo "key verification succeeded!"; \
#                 mv /tmp/nginx_signing.rsa.pub /etc/apk/keys/; \
#             else \
#                 echo "key verification failed!"; \
#                 exit 1; \
#             fi \
#             && apk del .cert-deps \
#             && apk add -X "https://nginx.org/packages/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
#             ;; \
#         *) \
# # we're on an architecture upstream doesn't officially build for
# # let's build binaries from the published packaging sources
#             set -x \
#             && tempDir="$(mktemp -d)" \
#             && chown nobody:nobody $tempDir \
#             && apk add --no-cache --virtual .build-deps \
#                 gcc \
#                 libc-dev \
#                 make \
#                 openssl-dev \
#                 pcre-dev \
#                 zlib-dev \
#                 linux-headers \
#                 libxslt-dev \
#                 gd-dev \
#                 geoip-dev \
#                 perl-dev \
#                 libedit-dev \
#                 mercurial \
#                 bash \
#                 alpine-sdk \
#                 findutils \
#             && su nobody -s /bin/sh -c " \
#                 export HOME=${tempDir} \
#                 && cd ${tempDir} \
#                 && hg clone https://hg.nginx.org/pkg-oss \
#                 && cd pkg-oss \
#                 && hg up -r 450 \
#                 && cd alpine \
#                 && make all \
#                 && apk index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
#                 && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
#                 " \
#             && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
#             && apk del .build-deps \
#             && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
#             ;; \
#     esac \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -n "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
    && if [ -n "/etc/apk/keys/nginx_signing.rsa.pub" ]; then rm -f /etc/apk/keys/nginx_signing.rsa.pub; fi \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Bring in tzdata so users could set the timezones through the environment
# variables
    && apk add --no-cache tzdata \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80

STOPSIGNAL SIGTERM

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["startup"]
