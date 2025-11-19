ARG     DEBIAN_VERSION
FROM    debian:${DEBIAN_VERSION}
WORKDIR /usr/local
SHELL   ["/bin/bash", "-c"]

ADD     https://packages.sury.org/debsuryorg-archive-keyring.deb /tmp/debsuryorg-archive-keyring.deb

RUN     --mount=type=bind,source=./.env,target=/tmp/.env <<EOD
# Set context
source /etc/os-release
source /tmp/.env
echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections

# Add the Sury Distro for loading PHP to trusted sources

apt-get update; apt-get install -y --no-install-recommends ca-certificates
dpkg -i /tmp/debsuryorg-archive-keyring.deb
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] " \
     "https://packages.sury.org/php/ $VERSION_CODENAME main" \
     > /etc/apt/sources.list.d/php.list

PHP="php${PHP_VERSION}"
packages=(
    logrotate python3-docker tini redis busybox               # Core bits
    mariadb-backup mariadb-client mariadb-server              # MariaDB
    nmap tree xz-utils vim                                    # Misc dev goodies
    apache2 apache2-utils certbot                             # Apache2.4 and Certbot
    $PHP-cli $PHP-fpm $PHP-bcmath $PHP-curl $PHP-gd $PHP-gmp  # PHP CLI and FPM core
    $PHP-imap $PHP-mbstring $PHP-mysql $PHP-redis $PHP-xml 
    $PHP-zip                                                  #   plus extra mods needed
    python3-schedule python3-docker                           # Extra Python Libraries
    libapache2-mod-evasive                                    # DDoS defence
    libapache2-mod-geoip geoip-database                       # Add GeoIP filering
)
apt-get update; apt-get install -y --no-install-recommends ${packages[@]}
EOD

# Busybox provides minimal versions of common UNIX utilities in a single small executable.
# This to used to facilate interactive debugging / trouble-shooting from with a container.
# Command are either passed as arg1 to busibox or by decoding a symlink name to it. This
# code loops over the command that busibox implements and adds the appropriate synlink
# if the command isn't defined.  That's 75 extra /usr/bin commands and 29 extra /usr/sbin
# ones for the sake of a 2.9 Mb executable.

RUN <<EOD
BB_CMDS="$(busybox|sed '1,/^Cur/d;s/.*\[\[//;s/,//g')"
SBIN_CMDS=(
    acpid adjtimex arp arping brctl depmod fdisk ifconfig ifdown ifup insmod
    ipneigh klogd loadfont loadkmap logread lsmod mdev mkdosfs modinfo modprobe
    nameif partprobe rdate rmmod route syslogd udhcpc vconfig watchdog
)
declare -A SBIN; for c in ${SBIN_CMDS[@]}; do SBIN[$c]='s'; done
for cmd in $BB_CMDS; do
    [[ -e "/bin/$cmd" || -e "/sbin/$cmd" ]] && continue
    echo "/usr/${SBIN[$cmd]}bin/$cmd -> /bin/busybox"
    ln -s  /bin/busybox -T /usr/${SBIN[$cmd]}bin/$cmd
done
rm /usr/bin/httpd # apache2 is already installed!
EOD

# HEALTH WARNING. In general the debian packages assume that the package will be used
# in a system or VPS that is multiprocess and initialised using systemd, rather than
# as a singeton damon running in a container enviroment where it is usually
# intialised using tini.  So the image contains quite a lot of detritis that isn't
# used especially in the /etc configs and the bin PATH: but too much hassle to remove.
#
# All of the www file tree is owned by the forum account with the uid:gid inherited from
# the host parent forum account. PHP and the cronjobs run in this account including the
# docker callback run in this account.  www-data is also member of the forum group and 
# this give apache read accees to the www file tree as PHP creats all files with a 
# default 0640 mode.
#
# Service     UID       GID       SocGID    SocMode
#  schedule   forum     docker    N/A       
#  httpd      www-data  www-data  N/A  
#  mariadb    mysql     mysql     mysql     0666       Implements access control
#  php        forum     forum     forum     0660       Apache in forum group with g:rw access
#  redis      redis     redis     redis     0666       Implements access control

RUN --mount=type=bind,source=./.env,target=/tmp/.env <<EOD
set -eax
source /tmp/.env

addgroup --gid $FGID $FORUM_USER
adduser  --uid $FUID --gid $FGID --comment "N/A" --disabled-password $FORUM_USER
adduser    www-data forum

# Add .my.cnf for FORUM_USER to enable DB access
FORUM_CNF=/home/forum/.my.cnf
cat > $FORUM_CNF <<-EOC
	[client]
	user=$MYSQL_USER
	password='$MYSQL_PASSWORD'
	database=$MYSQL_DATABASE
	[mysqldump]
	user=$MYSQL_USER
	password='$MYSQL_PASSWORD'
EOC
chmod 700 $FORUM_CNF; chown $FORUM_USER:$FORUM_USER $FORUM_CNF

# Edit the /etc/logrotate.d files for apache2, php-fpm and redis so that these do the required log rotations
# Apache2
sed -i '3i \\tmaxsize 50M\
\tdateext
/prerotate/,+4d
/if /,+2c \\t\tkill -USR1 $(cat /run/apache2/apache2.pid)
' /etc/logrotate.d/apache2
# php-fpm
sed  -i   '1s/php.* /php\/www.log /;2i \\tcreate
/if /,/fi$/c \\t\tkill -USR1 $(cat /run/php/php8.1-fpm.pid)
' /etc/logrotate.d/php8.1-fpm
# redis
sed -i '2i\ \tsu redis redis\
\tcreate
' /etc/logrotate.d/redis-server
EOD

# Use tini as entrypoint
ENTRYPOINT ["/usr/bin/tini", "--"]

# Command to start the container supervisor
CMD ["/usr/local/sbin/supervisor.py"]
