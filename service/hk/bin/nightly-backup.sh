#! /bin/bash
#
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

[ "$VHOST" == "forum" ] || exit   # backups are only implemented on the live forum

umask 117
cd /backups

DATE=$(date +%F)

echo -n "$(date -u) Starting SQL backup" > /proc/1/fd/1
#                   ===================

# Pass "backup" request to mysql container
echo ${VHOST} mysql backup >/run/host-callback.pipe

# Do the incremental tar of the www hierarchy

if [ "$(date +%d)" = "01" ]; then    # Do monthly backup on 1st of month
  TYPE="monthly"
  LEVEL="1"
  cp -p backups/ipb-level1.snar backups/ipb-level1.snar_old
else                                 # Do daily backup on other days
  TYPE="daily"
  LEVEL="2"
  cp -p backups/ipb-level2.snar backups/ipb-level2.snar_old
fi
  
tar --directory=/var/www --listed-incremental=backups/ipb-level$LEVEL.snar \
    --create --anchored --exclude ipb/datastore/* \
    --file=backups/${DATE}-var_www-$TYPE.tar \
    ipb

test "$LEVEL" = "1" && cp backups/ipb-level1.snar backups/ipb-level2.snar

echo -n "$(date -u) Finished www backup" > /proc/1/fd/1
#                   ===================

# Cull any daily backups prior to the previous month.  Calculating this cut-off is
# a bit convolved Alpine's BusyBox date doesn't do offsets

let DD=$(date +%-d)                            # Current day of this month
let UTS_MM01=$(date -d $(date +%Y-%m-01) +%s)  # Unix time for midnight 1st of month
let UTS_pMlD=$((UT_MM01-86400))                # Unix time for midnight 1 day early
let PMLD=$(date -d @$UT_pMlD +%d)              # Number of days last month
let DAYS=$((PMLD+DD-1))                        # mtime offset

cd sql-backups
DELSQLS=$(find  *.sql.xz -mtime +$DAYS ! -name "20??-??-01.sql.xz")
[ -n "$DELSQLS" ] && ( echo -n "$(date -u) Culling old SQL backups: "
                       rm -v $DELSQLS ) > /proc/1/fd/1

cd ../backups
DELTARS=$(find *-var_www-daily.tar -mtime +$DAYS)
[ -n "$DELSQLS" ] && ( echo -n "$(date -u) Culling old daily tar backups: "
                       rm -v $DELTARS) > /proc/1/fd/1