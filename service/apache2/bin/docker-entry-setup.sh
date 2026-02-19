 
# Define Apache2. Note that it takes its config from ./conf and ignores /etc/apache2
SERVICE="apache2"
COMMAND="apache2"
OPTS="-DFOREGROUND -f /usr/local/conf/apache2.conf"

set -vx

# Add symlink(s) to resolve modules and config DBs
maxminddb="/usr/local/bin/.mod_lib/mod_maxminddb.so"
countyDB="/usr/local/conf/.maxmind/GeoLite2-Country.mmdb"
AdminIPs="/usr/local/etc/apache2/ReqireAdminIPs.conf"
ln -sf /usr/lib/apache2/modules
if [[ -f ${maxminddb} && -f ${countyDB} ]] ; then
  ln -sf ${maxminddb} modules
  OPTS="-D UseMaxmind ${OPTS}"
fi

mkdir -p ${AdminIPs%/*}
ipbar="(${APACHE_ADMIN_IP// /|})"
echo "RewriteCond %{REMOTE_ADDR}  ${ipbar//\./\\.}  [OR]" > ${AdminIPs}

# Env vars for Apache2
APACHE_ADMIN_MATCH="(${APACHE_ADMIN_IP// /|})"
export APACHE_ADMIN_MATCH="${APACHE_ADMIN_MATCH//\./\\.}"
export APACHE_RUN_GROUP=www-data
export APACHE_RUN_USER=forum
export APACHE_PID_FILE=/var/run/apache2/apache2.pid
export APACHE_RUN_DIR=/var/run/apache2
export APACHE_LOCK_DIR=/var/lock/apache2
export APACHE_LOG_DIR=/var/log/apache2
export APACHE_GEO_MMDB=${countyDB}
export HOST_IP=$(ip addr show dev eth0 | awk '/inet /{split($2,a,"/");print a[1]}')

