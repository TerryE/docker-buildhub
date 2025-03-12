#! /bin/bash
set -eax
date -u
function entry_setup {
  ## Note that httpd takes its config from /usr/local/conf and ignores /etc/apache2
  # All modified conf files are mapped into /usr/local/conf so no tweeks needed other than
  # a symlink to resolve modules
  
  ln -sf /usr/lib/apache2/modules
  mkdir -p /var/run/apache2
  export APACHE_RUN_GROUP=www-data
  export APACHE_RUN_USER=www-data
  export APACHE_PID_FILE=/var/run/apache2/apache2.pid
  export APACHE_RUN_DIR=/var/run/apache2
  export APACHE_LOCK_DIR=/var/lock/apache2
  export APACHE_LOG_DIR=/var/log/apache2
  
  # The config binds to the actual IP, so do a bit of ip magic to set up HOST_IP
  export HOST_IP=$(ip addr show dev eth0 | grep inet | cut -b 10- |cut -d / -f 1)
  TINI_PREFIX="setpriv --reuid redis --regid redis --"
}
. /etc/docker-entry-helper --parent apache2 "-DFOREGROUND -f /usr/local/conf/httpd.conf"
