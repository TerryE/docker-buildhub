 
# Define Apache2. Note that it takes its config from ./conf and ignores /etc/apache2
SERVICE=apache2
COMMAND="apache2"
OPTS="-DFOREGROUND -f /usr/local/conf/apache2.conf"

# Add symlink to resolve modules
ln -sf /usr/lib/apache2/modules

export APACHE_RUN_GROUP=www-data
export APACHE_RUN_USER=forum
export APACHE_PID_FILE=/var/run/apache2/apache2.pid
export APACHE_RUN_DIR=/var/run/apache2
export APACHE_LOCK_DIR=/var/lock/apache2
export APACHE_LOG_DIR=/var/log/apache2
export HOST_IP=$(ip addr show dev eth0 | awk '/inet /{split($2,a,"/");print a[1]}')

