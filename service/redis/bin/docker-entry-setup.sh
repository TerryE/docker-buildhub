
set -eax
SERVICE=redis
USER=redis
USE_RUNSOCK=true
RUNMODE=0777
USE_VARLOG=true
REUID=redis
COMMAND=redis-server
OPTS="/etc/redis/redis.conf"

#  These are the Redis conf settings that need changing

HOST_IP=$(ip addr show dev eth0 | awk '/inet /{split($2,a,"/");print a[1]}')
PASSWD=$(cat /run/secrets/redis-pwd) 

# Enable conf.d for redis
mkdir -m 0770 -p /etc/redis/conf.d
echo "include /etc/redis/conf.d/*.conf" >> /etc/redis/redis.conf

cat > /etc/redis/conf.d/forum.conf <<-EOC
	protected-mode yes
        port 0
	loglevel notice
	syslog-enabled no
	databases 4
	requirepass $PASSWD
	unixsocket /run/redis/redis-server.sock
	unixsocketperm 777
	maxmemory 64mb
	maxmemory-policy allkeys-lru
	daemonize no
EOC
chown redis:redis -R /etc/redis
cd /var/lib/redis
