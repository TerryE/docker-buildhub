#! /bin/bash
function entry_setup() {
    set -eax
    mkdir -p /var/log/redis; chown redis:redis /var/log/redis
    mkdir -p /var/run/redis; chown redis:redis /var/run/redis

    #  These are the Redis conf settings that need changing

    HOST_IP=$(ip addr show dev eth0 | grep inet | cut -b 10- |cut -d / -f 1)
    PASSWD=$(cat /run/secrets/redis-pwd) 
    sed -i "/^bind /s/.*/bind ${HOST_IP}/
            /loglevel /s/.*/loglevel notice/
            /syslog-enabled /s/.*/syslog-enabled no/
            /databases /s/.*/databases 4/
            /^\(# \)\{0,1\}requirepass /s/.*/requirepass $PASSWD/
            /^\(# \)\{0,1\}unixsocket /s/.*/unixsocket \/run\/redis\/redis-server.sock/
            /^\(# \)\{0,1\}unixsocketperm /s/.*/unixsocketperm 770/
            /^\(# \)\{0,1\}maxmemory /s/.*/maxmemory 64mb/
            /^\(# \)\{0,1\}maxmemory-policy /s/.*/maxmemory-policy allkeys-lru/" /etc/redis/redis.conf

    cd /var/lib/redis
    find . \! -user redis -exec chown redis '{}' +
}

echo "$(date -u) Entering $SERVICE startup" > /proc/1/fd/1
entry_setup
echo "$(date -u) Initiating $SERVICE with redis owndership" > /proc/1/fd/1
#exec setpriv --reuid=redis --regid=redis --init-groups redis-server /etc/redis/redis.conf
sleep 3600
