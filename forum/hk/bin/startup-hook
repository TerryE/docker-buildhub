#! /bin/bash
#
#  Housekeeping start-up hook
#
echo "$(date -u) Entering Housekeeping  hook" > /proc/1/fd/1

cp    conf/crontab  /etc/crontabs/root
chown 0:0           /etc/crontabs/root
 
echo "$(date -u) PHP config updated" > /proc/1/fd/1
