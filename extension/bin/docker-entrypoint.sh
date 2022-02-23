#!/bin/bash

# Docker startup for Alpine Containers.
# The ENV variable HOSTNAME selects the init required

set -e

start_apache () {
  # Apache gets grumpy about PID files pre-existing
  rm -f logs/httpd.pid
  [ -L modules ] || ln -s /usr/lib/apache2 -T modules
  [ -z "$1" ] && exec httpd -d $(pwd) -DFOREGROUND -f conf/httpd.conf
  exec "$@"
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

start_housekeeping () {
  [ -d /var/log/cron ] || mkdir /var/log/cron
  # symlink to the local crontab
  [ -f conf/crontab ] && ln -s $(pwd)/conf/crontab /etc/crontabs/root
  # crond needs to be controlled by tini to handle shutdown requests
  exec tini /usr/sbin/crond -f -l 2 -L /var/log/cron/cron.log -c /etc/crontabs
}

#
#  ========================= Entry point =========================
#
[ -d /var/log/${HOSTNAME} ] || mkdir /var/log/${HOSTNAME} # Make log dir if needed
cd /usr/local
#
# Use the local Docker entrypoint, if defined in the local ${HOSTNAME}/bin folder)
#
[ -f ${HOSTNAME}/bin/docker-entrypoint ] && \
     exec ${HOSTNAME}/bin/docker-entrypoint "$@"

#
# Otherwise use this script. Change to local/${HOSTNAME} if it exists.
#
[ -d ${HOSTNAME}/bin ] && export PATH="/usr/local/${HOSTNAME}/bin:${PATH}"
[ -d ${HOSTNAME} ] && cd  ${HOSTNAME}
#
# Ccall an optional startup hook if it  exists in the current bin folder, so  
# the container can customise /etc and other files before starting the service.
#
[ -f  bin/startup-hook ] && source bin/startup-hook "$@"

echo "$(date -u) Entering ${HOSTNAME} start-up" 

case "${HOSTNAME}" in
    apache2)  start_apache        "$@" ;;
    php)      start_php           "$@" ;;
    redis)    start_redis         "$@" ;;
    hk)       start_housekeeping  "$@" ;;
    *)        exec                "$@" ;;
esac
