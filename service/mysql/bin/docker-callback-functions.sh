
function CB_rotate_logs { rotateLogs; }

function CB_nightly_backup { USR="$1"
    declare -i t=$SECONDS
    DATE=$(date "+%F")
    DUMPFILE=/backups/sql-backups/$DATE.sql
    umask 0007
    mysqldump --opt ipb > $DUMPFILE
    logInfo "$(date -u) SQL backup completed in $((SECONDS-t)) secs"
    nice xz -T 4 $DUMPFILE
    chown $USR:$USR $DUMPFILE.xz
    logInfo "$(date -u) + SQL compression completed in $((SECONDS-t)) secs"
}
