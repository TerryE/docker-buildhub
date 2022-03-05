ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

#ARG HOST_USER
#ENV HOST_USER ${HOST_USER}

# Swap www-data:www-data to the Debian standard 33:33 and install bash as default shell

RUN   deluser xfs; delgroup www-data; addgroup -g 33 www-data; \
      adduser -G www-data -S -u 33 -H -D www-data; \
      apk update; apk add bash
SHELL ["/bin/bash", "-c"]

WORKDIR /usr/local

# These are all the non-core Alpine packages used to service a LAMP stack (less MySQL
# which requires fairly complex startup, so this uses a standard official container).  The
# CORE, APACHE and PHP list below are required in the image to enable the services apache,
# php-fpm, redis or cron to be executed in a container based on this image.  The GOODIES
# list are useful for debugging at the bash prompt.
#
# Also add aliases dropping the 8 from PHP names and paths

RUN   CORE='certbot logrotate su-exec redis tini'; \
      APACHE='apache2 apache2-ssl apache2-proxy'; \
      PHP_MODS='fpm bcmath curl dom exif fileinfo gd gmp imap mbstring mysqli openssl \
          phar redis session simplexml sodium xml xmlreader xmlwriter opcache zip'; \
      PHP=$(echo php8; for m in ${PHP_MODS}; do echo -n " php8-${m}"; done); \
      GOODIES='iputils nmap procps tree util-linux xz'; \
      apk add ${CORE} ${APACHE} ${PHP} ${GOODIES}; \
      ln -sT /usr/sbin/php-fpm{8,};\
      ln -sT /usr/bin/php{8,}; \
      ln -sT /etc/php{8,}

# The docker-entrypoint command sets the context to start the command as a docker daemon
# service and executes the command to start the relevant daemon for the container (this
# command can be overridden in compose service definition).

# The configuration of the various docker entrypoint and callback scripts
COPY docker-*.sh bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]