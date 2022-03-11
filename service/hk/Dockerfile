ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

#ARG HOST_USER
#ENV HOST_USER ${HOST_USER}

# Swap www-data:www-data to the Debian standard 33:33

RUN \
  deluser xfs; delgroup www-data; addgroup -g 33 www-data; \
  adduser -G www-data -S -u 33 -H -D www-data; \
  apk update; apk add  --no-cache bash

SHELL ["/bin/bash", "-c"]

WORKDIR /usr/local

# These are all the non-core Alpine packages used to service the housekeeping, nginx,
# php-fpm, redis and sshd services. (The MySQL service requires fairly complex startup,
# so it is easier here just to use a standard official Docker image).  The  CORE .. SSH
# PHP lists below are required for the coresponding services.  The GOODIES list is useful
# for debugging at the bash prompt.

RUN \
  CORE='certbot logrotate su-exec redis tar tini'; \
  APACHE='apache2 apache2-ssl apache2-proxy'; \
  PHP_MODS='fpm bcmath curl ctype dom exif fileinfo gd gmp imap mbstring mysqli \
      openssl phar redis session simplexml sodium xml xmlreader xmlwriter opcache zip'; \
  PHP=$(echo php8; for m in ${PHP_MODS}; do echo -n " php8-${m}"; done); \
  SSH='openssh-server openssh-server-pam openssh-sftp-server rsync'; \
  GOODIES='iputils nmap procps tree util-linux xz'; \
  \
  apk add ${CORE} ${APACHE} ${PHP} ${SSH} ${GOODIES};   # Add the packages \
  rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*         # Clean up temp & working dirs

# The docker-entrypoint.sh command sets the context to start the tailored service as a
# docker daemon.  Note that this isn't actually present in the base image as the various
# /usr/local subfolders are mapped in the Docker compose file.

ENTRYPOINT ["docker-entrypoint.sh"]
