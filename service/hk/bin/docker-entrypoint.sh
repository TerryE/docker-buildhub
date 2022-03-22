#! /bin/bash

echo "$(date -u) Entering Housekeeping startup" > /proc/1/fd/1
#                =============================

[ -d /var/log/cron ]  || mkdir /var/log/cron  # Make log dir if needed

# Copy root crontab into etc

cp    conf/crontab  /etc/crontabs/root
chown 0:0           /etc/crontabs/root
 
#  -  For simplicity the /var/log directory is shared between all services so all the
#     log rotation is done as part of housekeeping.  All other services have the log
#     rotation configs removed.
#
#  -  Where the remote service caches the logfile FD, it needs to be notified to flush
#     logs, and this is done as a postrotate callback to the remote service.
#
#  -  The apache2 (httpd), php, and redis packages install log rotate conf file but the
#     first two need tweaking
#
#  -  cron needs a conf file adding
#
#  -  mysql and sshd are low volume use Docker logging

echo -e "/var/log/cron/*.log {
  weekly\n  missingok\n  rotate 8\n  compress\n  notifempty
}" > /etc/logrotate.d/cron

echo -e "/var/log/sshd/*.log {
  weekly\n  missingok\n  rotate 8\n  compress\n  notifempty
}" > /etc/logrotate.d/sshd

mv /etc/logrotate.d/{php-fpm8,php}
rm -f /etc/logrotate.d/acpid
sed -i \
    '/postrotate/{n;s!/.*!echo ${VHOST} php flushlogs >/run/host-callback.pipe!}' \
    /etc/logrotate.d/php
sed -i \
    '/postrotate/{n;s!/.*!echo ${VHOST} httpd flushlogs >/run/host-callback.pipe!}' \
    /etc/logrotate.d/apache2

echo "$(date -u) Housekeeping config updated: crond started" > /proc/1/fd/1
#                ==========================================

# if the first arg is present but not an option then exec it, otherwise crond needs to be
# controlled by tini to handle shutdown requests, but append any options

[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"
exec tini /usr/sbin/crond -f -l 7 -L /var/log/cron/cron.log -c /etc/crontabs "$@"
