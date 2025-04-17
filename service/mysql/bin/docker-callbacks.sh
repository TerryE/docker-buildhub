
function CB_rotate_logs { rotateLogs; }

function CB_nightly_backup { USR="$1"
    declare -i t=$SECONDS
    DATE=$(date "+%F")
    DUMPFILE=/backups/sql-backups/$DATE
    logInfo "$(date -u) + SQL compression completed in $((SECONDS-t)) secs"
    umask 0007
    mysqldump --opt ipb > $DUMPFILE.sql
    logInfo "$(date -u) SQL backup completed in $((SECONDS-t)) secs"
    nice xz -T 4 $DUMPFILE.sql
    chown $USR:$USR $DUMPFILE.sql.xz
    local MD$5=$(md5sum $DUMPFILE.sql.xz)
    mv $DUMPFILE{,-${MD5%% *}}.sql.xz
}
