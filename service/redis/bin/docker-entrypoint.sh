#! /bin/bash

echo "$(date -u) Entering Redis startup" > /proc/1/fd/1
#                ======================

[ -d /var/log/redis ] || mkdir  # Make log dir if needed
chown redis /var/log/redis

#  These are the Redis conf settings that need changing

export HOST_IP=$(ip addr show dev eth0 | grep inet | cut -b 10- |cut -d / -f 1)
sed -i "/^bind /s/.*/bind ${HOST_IP}/
        /loglevel /s/.*/loglevel notice/
        /syslog-enabled /s/.*/syslog-enabled no/
	/databases /s/.*/databases 4/
        /^# maxmemory /s/.*/maxmemory 8mb/
        /^# maxmemory-policy /s/.*/maxmemory-policy allkeys-lru/" /etc/redis.conf

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
exec su-exec redis redis-server /etc/redis.conf --requirepass $(cat /run/secrets/redis-pwd) \
                                                --maxmemory 64mb "$@"
