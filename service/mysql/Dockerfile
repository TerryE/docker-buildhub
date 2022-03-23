ARG MYSQL_VERSION
FROM mysql:${MYSQL_VERSION}

SHELL ["/bin/bash", "-c"]

WORKDIR /usr/local

# The MySQL service requires fairly complex startup, so it is easier here just to use extend 
# the standard official Docker image with a few extra components to allow IP resolution and
# ones useful for debugging at the bash prompt.

RUN set -eux; \
  PKGS='tini iproute2 nmap procps tree util-linux vim-tiny'; \
  apt-get update; \
	apt-get install -y --no-install-recommends ${PKGS}; \
	rm -rf /var/lib/apt/lists/* /tmp/*
