set -eax
SERVICE=sshd
USE_VARLOG=true
COMMAND="/usr/sbin/sshd"
#OPTS="-D -E /var/log/sshd/sshd.log"
OPTS="-D -E /proc/1/fd/1"

# Delete the root .ssh directory as a double-check
[ -d /root/.ssh ] && rm -rf /root/.ssh

mkdir -m 700 -p /backups/home/.ssh
cp /run/secrets/authorized_keys /backups/home/.ssh
chown backups:forum -R /backups/home
chmod o-rw,g-rw -R /backups/home

cat > /etc/ssh/sshd_config.d/forum.conf <<-EOC
	Port 22
	PasswordAuthentication no
	PermitRootLogin no
	LogLevel INFO
EOC
