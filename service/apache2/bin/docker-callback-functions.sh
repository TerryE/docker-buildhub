
function CB_rotate_logs { rotateLogs; }

function CB_certbot {

return   # For now !!!
    # If the current certificate is older than ~2 months, then create a certbot HTTP-01
    # challenge response directory, run certbot and clean up
    OLDCERT=$(find /etc/letsencrypt/live/forum.${DOMAIN}/fullchain.pem -mtime +61)
    if [ -n "$OLDCERT" ]; then
      (
        msgInfo "$(date -u) Checking / Renewing *.${DOMAIN} certificates"
        mkdir /var/www/acme; chown www-data:www-data /var/www/acme
        certbot certonly -n -d forum.${DOMAIN},www.${DOMAIN},test.${DOMAIN} \
                         --webroot -w /var/www/acme
        rm -rf /var/www/acme
      )
    else
      msgInfo "$(date -u) Skipping certificate renewal"
    fi
}

CB_nighty_backup {
    return

# Backup the IPS system to ~forum/backups
#
# The backup strategy only saves the data in the ipb database and the file
# hierarchy in /var/www/ipb.
#
# -  A callback is issued to the mysql server to dump the database to file; It is then xz
#    compressed to a dated backup in the /backups/sql-backups folder, this compression
#    takes a few mins.  This script does the FS backup in parallelc to keep the file and
#    DB backups as close as possible.
#
# -  The file hierarchy uses a multi level backup
#
#    Level 0    A full backup
#    Level 1    A monthly incremental (on the 1st of the month)
#    Level 2    A daily incremental
#
#    The last full backup was as the last migration (Aug 2018) and is 15Gb.  The daily
#    incrementals are currently 20-50Mb depending on images uploaded, monthly 500Mb-1Gb.
#
# Retention
#
# -  Monthly incrememtal backups are retained indefinitely.
#
# -  Enough daily TAR backups are retained to enable in-extremis roll back over the last
#    ~4+ weeks.  This is achieved by culling dailies older than the first of the previous
#    month.
#
# -  The SQL backups are daily full compressed SQL dumps.  The dumps from the first of the
#    month are retained.  On the 1st of the month the dump all of the remaining daily
#    backups prior to the previous month are also culled.
#
# Note that the filetree being backyup and the destination /backups folder are both
# owned by www-data, so the tar is itself run as www-data.

[ "$VHOST" == "forum" ] || exit   # backups are only carried out on the live forum
  
umask 0007
cd /backups

exec 2>/proc/1/fd/2  # log errors to docker logs

tar-backup() {
  local DATE=$(date +%F)
  local LEVEL="$1"
  local TYPE="$2"
  local SNAR=backups/ipb-level${LEVEL}.snar

  cp -p ${SNAR} ${SNAR}_old

  su-exec www-data tar \
    --directory=/var/www --listed-incremental=${SNAR} \
    --create --anchored --exclude ipb/datastore/* \
    --file=backups/${DATE}-var_www-${TYPE}.tar    ipb

  [ "$LEVEL" = "1" ] && cp -p  backups/ipb-level{1,2}.snar
}

echo -n "$(date -u) Starting SQL backup" > /proc/1/fd/1
#                   ===================

# Pass "backup" request to mysql container
host-callback.sh mysql backup

# Do the incremental tar of the www hierarchy
if [ "$(date +%d)" = "01" ]; then
  tar-backup 1 monthly     # Do level 1 monthly backup on 1st of month
else
  tar-backup 2 daily       # Do level 2 daily backup on other days
fi
  
echo -n "$(date -u) Finished www backup" > /proc/1/fd/1
#                   ===================

# Cull any daily backups prior to the previous month.  Calculating this cut-off is
# a bit convolved as Alpine's BusyBox date doesn't do offsets

let DD=$(date +%-d)                            # Current day of this month
let UTS_MM01=$(date -d $(date +%Y-%m-01) +%s)  # Unix time for midnight 1st of month
let UTS_pMlD=$((UTS_MM01-86400))               # Unix time for midnight 1 day early
let PMLD=$(date -d @$UTS_pMlD +%d)             # Number of days last month
let DAYS=$((PMLD+DD-1))                        # mtime offset

cd sql-backups
DELSQLS=$(find  *.sql.xz -mtime +$DAYS ! -name "20??-??-01.sql.xz")
[ -n "$DELSQLS" ] && ( echo -n "$(date -u) Culling old SQL backups: "
                       rm -v $DELSQLS ) > /proc/1/fd/1

cd ../backups
DELTARS=$(find *-var_www-daily.tar -mtime +$DAYS)
[ -n "$DELTARS" ] && ( echo -n "$(date -u) Culling old daily tar backups: "
                       rm -v $DELTARS) > /proc/1/fd/1
}

