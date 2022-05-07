#! /bin/bash

# Service callbacks for service mysql

# check if a separate callback is handling the call
[ -f /usr/local/sbin/service-$1 ] && exec /usr/local/sbin/service-$1 "$@"

case $1 in
  backup)
    ((t = SECONDS))
    DATE=$(date "+%F")
    umask 0007
    mysqldump --opt ipb > /tmp/ipb.sql
    xz /tmp/ipb.sql
    chown www-data:www-data /tmp/ipb.sql.xz
    mv {/tmp/ipb,/backups/sql-backups/$DATE}.sql.xz
    echo "$(date -u) SQL backup completed in $((SECONDS-t)) secs." \
       > /proc/1/fd/1 ;;

  flushlogs)
    mysqladmin flush-logs  ;;

  *) ;;
esac
