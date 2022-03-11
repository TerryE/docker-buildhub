#! /bin/bash

echo "$(date -u) Entering Redis startup" > /proc/1/fd/1
#                ======================

[ -d /var/log/redis ] || mkdir  # Make log dir if needed
chown redis /var/log/redis

#  These are the Redis conf settings that need changing

sed -i '/databases /s!.*!databases 4!
        /syslog-enabled /s!.*!syslog-enabled no!
        /^\(# \)\?maxmemory /s!.*!maxmemory 8mb!
        /^\(# \)\?maxmemory-policy /s!.*!maxmemory-policy allkeys-lru!' /etc/redis.conf

# The logrotate callback only needs to rotates the logs for Redis, so drop rest.  Note
# that Redis doesn't cache the logfile open, so no need for a graceful reload

rm $(find /etc/logrotate.d/* -not -name $HOSTNAME)

# set context to redis lib and make sure al

cd /var/lib/redis
find . \! -user redis -exec chown redis '{}' +


echo "$(date -u) Redis startup: starting Redis service" > /proc/1/fd/1
#                =====================================

# if the first arg is not an option then exec it, otherwise append as options
  
[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"
exec tini su-exec redis redis-server /etc/redis.conf \
                    --requirepass $(cat /run/secrets/redis-pwd) \
                    --maxmemory 64mb --loglevel verbose "$@"
