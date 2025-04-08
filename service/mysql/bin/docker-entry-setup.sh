SERVICE=mysql
USER=mysql
USE_RUNSOCK=true
USE_VARLOG=true
COMMAND="mariadbd"
OPTS="--datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --skip-networking"
# Copy any local conf files into the MySQL conf.d folder to be scanned on startup
cp /usr/local/conf/* /etc/mysql/conf.d/
