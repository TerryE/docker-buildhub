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

start_php-fpm () {
  [ -z "$1" ] ||   exec "$@"
  exec php-fpm -c conf/php -y conf/php-fpm.d/www.conf -F
}

start_redis () {
  # if the first arg is present but not an option then exec it
  [ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"

  # otherwise append as options
  exec redis-server --requirepass $(cat /run/secrets/redis-pwd) --maxmemory 64mb "$@"
}

start_housekeeping () {
  [ -d /var/log/cron ] || mkdir /var/log/cron
  # symlink to the local crontab
  [ -f conf/crontab ] && ln -s $(pwd)/conf/crontab /etc/crontabs/root
  # crond needs to be controlled by tini to handle shutdown requests
  exec tini /usr/sbin/crond -f -l 2 -L /var/log/cron/cron.log -c /etc/crontabs
}
#
# Call startup hook if it exists (preferentially in the local $HOSTNAME/bin folder)
#
[ -d /usr/local/$HOSTNAME ] && cd /usr/local/$HOSTNAME && export PATH=$(pwd)/bin:${PATH}
[ -d /var/log/$HOSTNAME ] || mkdir /var/log/$HOSTNAME

[ -f bin/startup-hook ] && source bin/startup-hook "$@";
[ -f /usr/local/bin/startup-hook ] && source /usr/local/bin/startup-hook "$@";
#
# Use the local Docker entrypoint, if defined in the local $HOSTNAME/bin folder)
#
[ -f bin/docker-entrypoint ] && exec bin/docker-entrypoint "$@"
#
# Otherwise use the above start_XXXX function
#
case "$HOSTNAME" in
    apache2)  start_apache        "$@" ;;
    php-fpm)  start_php-fpm       "$@" ;;
    redis)    start_redis         "$@" ;;
    hk)       start_housekeeping  "$@" ;;
    *)        exec                "$@" ;;
esac
