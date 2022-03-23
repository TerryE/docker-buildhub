#!/bin/bash

echo "$(date -u) Entering MySQL startup" > /proc/1/fd/1
#                ======================

set -e

# setup /root/.my.cnf

PASSWD=$(</run/secrets/mysql-root)
echo -e "[client]\npassword='$PASSWD'\n[mysqldump]\npassword='$PASSWD'\n" >/root/.my.cnf

# Copy any local conf files into the MySQL conf.d folder to be scanned on startup
cp /usr/local/etc/* /etc/mysql/conf.d/

# if the first arg is present but not an option then exec it, otherwise chain to the
# stanard MySQL entrypoint script to do DB recovery, startup, etc, but append any options

echo "$(date -u) MySQL startup args " "$@" > /proc/1/fd/1
#                ==================

[ -n "$1" ] && [ "${1#-}" == "$1" ] && [ "$1" != "mysqld" ] && exec "$@"

echo "$(date -u) MySQL startup: chaining to standard entrypoint" > /proc/1/fd/1
#                ==============================================
exec tini -vv /usr/local/bin/docker-entrypoint.sh  "$@"

