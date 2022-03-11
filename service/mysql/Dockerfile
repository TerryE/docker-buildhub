ARG MYSQL_VERSION
FROM mysql:${MYSQL_VERSION}

SHELL ["/bin/bash", "-c"]

WORKDIR /usr/local

# These are all the non-core Alpine packages used to service the housekeeping, nginx,
# php-fpm, redis and sshd services. (The MySQL service requires fairly complex startup,
# so it is easier here just to use a standard official Docker image).  The  CORE .. SSH
# PHP lists below are required for the coresponding services.  The GOODIES list is useful
# for debugging at the bash prompt.

RUN set -eux; \
  PKGS='tini iproute2 nmap procps tree util-linux vim-tiny'; \
  apt-get update; \
	apt-get install -y --no-install-recommends ${PKGS}; \
	rm -rf /var/lib/apt/lists/* /tmp/*
