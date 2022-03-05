#!/bin/bash

# Docker startup for all Containers. The ENV variable HOSTNAME selects the init required

set -e

start_apache () {
  # Apache gets grumpy about PID files pre-existing
  rm -f logs/httpd.pid
  [ -L modules ] || ln -s /usr/lib/apache2 -T modules
  [ -z "$1" ] && exec httpd -d $(pwd) -DFOREGROUND -f conf/httpd.conf
  exec "$@"
}

start_housekeeping () {
  [ -d /var/log/cron ] || mkdir /var/log/cron
  # crond needs to be controlled by tini to handle shutdown requests
  exec tini /usr/sbin/crond -f -l 2 -L /var/log/cron/cron.log -c /etc/crontabs
}

start_mysql () {
  # Chain to the package entrypoint script to do DB recovery, etc.
  exec /usr/local/bin/docker_entrypoint.sh  "$@"
}

start_php () {
  [ -z "$1" ] ||   exec "$@"
  exec php-fpm -F
}

start_redis () {
  # set context to redis lib and make sure al
  cd /var/lib/redis
  find . \! -user redis -exec chown redis '{}' +

  # if the first arg is present but not an option then exec it
  [ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"

  # otherwise append as options
  exec su-exec redis redis-server --requirepass $(cat /run/secrets/redis-pwd) --maxmemory 64mb "$@"
}

#
#  ========================= Entry point =========================
#

[ -d /var/log/${HOSTNAME} ] || mkdir /var/log/${HOSTNAME} # Make log dir if needed

cd /usr/local

#
# Call an optional startup hook if it  exists in the current sbin folder, so
# the container can customise /etc and other files before starting the service.
#
[ -f  sbin/startup-hook.sh ] && sbin/startup-hook.sh "$@"

echo "$(date -u) Entering ${HOSTNAME} start-up"

case "${HOSTNAME}" in
    hk)       start_housekeeping  "$@" ;;
    httpd)    start_apache        "$@" ;;
    mysql)    start_mysql         "$@" ;;
    php)      start_php           "$@" ;;
    redis)    start_redis         "$@" ;;
    *)        exec                "$@" ;;
esac
