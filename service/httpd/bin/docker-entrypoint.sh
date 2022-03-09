#! /bin/bash

echo "$(date -u) Entering httpd server startup" > /proc/1/fd/1
#                =============================

[ -d /var/log/apache2 ] || mkdir /var/log/apache2 # Make log dir if needed

# We want logrotate to rotates the logs for httpd only, so fixup the logrotate entry and
# drop rest.  Note that issuing a USR1 to Apache2 tells it to do a graceful reload

mv /etc/logrotate.d/{apache2,httpd}
rm $(find /etc/logrotate.d/* -not -name httpd)
sed -in '/postrotate/{n;s!/.*!kill  -s USR1  1!}' /etc/logrotate.d/httpd

# All modified conf files are mapped into /usr/local/conf so no tweeks needed other than
# a symlink to resolve modules

ln -sfT /usr/lib/apache2 modules

# The config binds the VHOSTS to the actual IP, so do a bit of ip majic to get it

export HOST_IP=$(ip addr show dev eth0 | grep inet | cut -b 10- |cut -d / -f 1)

echo "$(date -u) httpd startup: starting httpd service" > /proc/1/fd/1
#                =====================================

# if the first arg is present but not an option then exec it, otherwise append to httpd

[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"
exec httpd -d $(pwd) -DFOREGROUND -f conf/httpd.conf "$@"
