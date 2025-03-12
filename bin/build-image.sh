#!/bin/bash

# Source in .env from the script's parent directory
CXT="$(dirname "$(readlink -fm "$0")")"
source $CXT/.env  # uses  PHP_VERSION  MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD FIUD FGID
rm $CTX/.env

#set -evx

echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections
apt-get update
apt-get install --yes --no-install-recommends lsb-release ca-certificates curl

# Add the Sury Distro for loading PHP

curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
dpkg -i /tmp/debsuryorg-archive-keyring.deb
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
     > /etc/apt/sources.list.d/php.list
apt-get update

PHP="php${PHP_VERSION}"

packages=(
    #
    # Install Core, SSH, DB and Goodies.  Note that docker-entrypoint script is bound on
    # a per container, so each container will be initiating only one process, for example
    # the httpd container runs apache2.  The "goodies" are really to all an admin to
    # debug issues in the running service by starting an interactive bash session.
    # Busybox is included to allow minimal versions of useful commands
    #
    logrotate python3-docker tini redis busybox               # Core bits
    openssh-server openssh-sftp-server rsync                  # OpenSSH
    mariadb-backup mariadb-client mariadb-server              # MariaDB
    nmap tree xz-utils vim                                    # Misc dev goodies
    apache2 apache2-utils certbot                             # Apache2.4 and Certbot
    $PHP-cli $PHP-fpm $PHP-bcmath $PHP-curl $PHP-gd $PHP-gmp  # PHP CLI and FPM core
    $PHP-imap $PHP-mbstring $PHP-mysql $PHP-xml $PHP-zip      # plus extra mods needed
)
apt-get install -y --no-install-recommends ${packages[@]}

# Busybox provides minimal versions of common UNIX utilities in a single small executable.
# This to used to facilate interactive debugging / trouble-shooting from with a container.
# Command are either passed as arg1 to busibox or by decoding a symlink name to it. This
# code loops over the command that busibox implements and adds the appropriate synlink
# if the command isn't defined.

BB_CMDS="$(busybox|sed '1,/^Cur/d;s/.*\[\[//;s/,//g')"
SBIN_CMDS=(
    acpid adjtimex arp arping brctl depmod fdisk ifconfig ifdown
    ifup insmod ipneigh klogd loadfont loadkmap logread lsmod mdev
    mkdosfs modinfo modprobe nameif partprobe rdate rmmod route
    syslogd udhcpc vconfig watchdog
)
declare -A SBIN; for c in ${SBIN_CMDS[@]}; do SBIN[$c]='s'; done

for cmd in $BB_CMDS; do
    [[ -e "/bin/$cmd" || -e "/sbin/$cmd" ]] && continue
    echo "/usr/${SBIN[$cmd]}bin/$cmd -> /bin/busybox"
    ln -s  /bin/busybox -T /usr/${SBIN[$cmd]}bin/$cmd
done

# HEALTH WARNING. In general the debian packages assume that the package will be used
# in a system or VPS that is multiprocess and initialised using systemd, rather than
# as a singeton damon running in a container enviroment where it is usually
# intialised using tini.  So the image contains quite a lot of detritis that isn't
# used especially in the /etc configs and the bin PATH: but too much hassle to remove.
#
# All periodic activities are run in the cron service using a root or a non-privileged
# housekeeping user.  See cron docker-entry script for more details
#
# Add Housekeeping Acco.  It's UID:GID is inherited from this scripts UID:GID
 
FORUM_USER=forum
addgroup --gid $FGID $FORUM_USER
adduser  --uid $FUID --gid $FGID --comment "N/A" --disabled-password forum
adduser   www-data forum
BUID=$((FUID+1))
adduser --uid $BUID --gid $FGID --home /backups/home --no-create-home \
	--comment "N/A" --disabled-password backups

# Service   UID       GID       SocGID    SocMode
#  cron     root      root      root      N/A
#  httpd    www-data  www-data  www-data  N/A
#  mariadb  mysql     mysql     mysql     0666       Implements access control
#  php      forum     forum     forum     0660       Apache in forum group with g:rw access
#  redis    redis     redis     redis     0666       Implements access control
#  sshd     root      root      N/A       N/A
#
# Add .my.cnf for  FORUM_USER to enable DB access

MY_CNF="/home/$FORUM_USER/.my.cnf"
echo -e "\n[client]\nuser=$MYSQL_USER\npassword='$MYSQL_PASSWORD'\ndatabase=$MYSQL_DATABASE\n" \
	"\n[mysqldump]\nuser=$MYSQL_USER\npassword='$MYSQL_PASSWORD'\n" \  > $MY_CNF
chmod 700 $MY_CNF; chown $FORUM_USER:$FORUM_USER $MY_CNF

cat>/etc/docker-entry-helper<<'EOD'
if [[ $1 = "--parent" ]]; then TINI_OPTS="-s -g"; shift; fi
SERVICE="$1"
OPTS="$2"
set -e

echo "$(date -u) Entering $SERVICE startup" > /proc/1/fd/1
mkdir -p /var/log/$SERVICE
[[ $(type -t entry_setup) = "function" ]] || exit;
entry_setup
echo "$(date -u) Initiating $SERVICE with tini" > /proc/1/fd/1
exec tini $TINI_OPTS $SERVICE -- $OPTS
EOD
