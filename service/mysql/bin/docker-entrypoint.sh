#!/bin/bash

echo "$(date -u) Entering MySQL startup" > /proc/1/fd/1
#                ======================

set -e
env> /proc/1/fd/1
[ -d /var/log/mysql ] || mkdir /var/log/mysql # Make log dir if needed

# setup /root/.my.cnf

PASSWD=$(</run/secrets/mysql-root)
echo -e "[client]\npassword='$PASSWD'\n[mysqldump]\npassword='$PASSWD'\n" >/root/.my.cnf


cp /usr/local/etc/* /etc/mysql/conf.d/

# if the first arg is present but not an option then exec it, otherwise chain to the
# stanard MySQL entrypoint script to do DB recovery, startup, etc, but append any options

[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"

echo "$(date -u) MySQL startup: chaining to standard entrypoint" > /proc/1/fd/1
#                ==============================================
exec /usr/local/bin/docker-entrypoint.sh  "$@"
