#! /bin/bash

set -eax
echo "$(date -u) Entering SSH server startup" > /proc/1/fd/1
#                ===========================
# SSHD used docker logging so no /var/log folder is needed

# The service only allows www-data login with /backups as the home directory, so set up
# the www-data account as interactive with an .ssh directory; remove the one for root
# because the only root access is through docker exec

# Make sure logs folder exists
mkdir -p /var/log/sshd 

# Delete the root .ssh directory as a double-check
[ -d /root/.ssh ] && rm -rf /root/.ssh

mkdir -m 700 -p /backups/home/.ssh
cp /run/secrets/authorized_keys /backups/home/.ssh
chown backups:forum -R /backups/home
chmod o-rw,g-rw -R /backups/home

# The host /etc/ssh is readonly mapped to /usr/local/conf; clone this to /etc/ssh and
# tweak a few settings

cp -a conf/* /etc/ssh
sed -i '/Port /s!.*!Port 22!
        /PasswordAuthentication/s!^.*!PasswordAuthentication no!
        /LogLevel /s!.*!LogLevel INFO!
        /\tsftp\t/s!openssh!ssh!' /etc/ssh/sshd_config

# No log rotation needed to cull the logrotate.d directory

rm -rf /etc/logrotate.d/*

echo "$(date -u) SSH Server startup: starting sshd service" > /proc/1/fd/1
#                =========================================

# if the first arg is not an option then exec it, otherwise append the args as options.
# Note that sshd needs to be tini-wrapped for orderly shutdown
[[ -d /run/sshd ]] || mkdir /run/sshd  
[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"
#sleep 86400
exec tini -s -g /usr/sbin/sshd -- -D -E /var/log/sshd/sshd.log "$@"
