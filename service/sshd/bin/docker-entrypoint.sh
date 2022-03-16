#! /bin/bash
#
echo "$(date -u) Entering SSH server startup" > /proc/1/fd/1
#                ===========================

# SSHD used docker logging so no /var/log folder is needed

# The service only allows www-data login with /backups as the home directory, so set up
# the www-data account as interactive with an .ssh directory; remove the one for root
# because the only root access is through docker exec

adduser -h /backups -s /bin/bash -G www-data -S -D -H backups

[ -d /backups/.ssh ] || mkdir -m 700 /backups/.ssh
[ -d /root/.ssh ]    && rm -rf /root/.ssh

[ -d /var/log/sshd ] ||  mkdir /var/log/sshd # Make sure logs folder exists

cp /run/secrets/authorized_keys /backups/.ssh
chown    backups:www-data      /backups
chown -R backups:www-data      /backups/.ssh

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
  
[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"
exec tini /usr/sbin/sshd.pam -D -E /var/log/sshd/sshd.log -f /etc/ssh/sshd_config "$@"
