#! /bin/bash

echo "$(date -u) Entering Housekeeping startup" > /proc/1/fd/1
#                =============================

[ -d /var/log/cron ]  || mkdir /var/log/cron  # Make log dir if needed

# Copy root crontab into etc

cp    conf/crontab  /etc/crontabs/root
chown 0:0           /etc/crontabs/root
 
#  For simplicity the /var/log directory is shared between all services so all the
#  log rotation is done as part of housekeeping, and all config is in the base 
#  logrotate.conf. All logrotate.d entries are removed to avoid confusion.

cp conf/logrotate.conf /etc
rm /etc/logrotate.d/*

echo "$(date -u) Housekeeping config updated: crond started" > /proc/1/fd/1
#                ==========================================

# if the first arg is present but not an option then exec it, otherwise crond needs to be
# controlled by tini to handle shutdown requests, but append any options

[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"
exec tini /usr/sbin/crond -f -l 7 -L /var/log/cron/cron.log -c /etc/crontabs "$@"
