
function CB_rotate_logs { rotateLogs; }

function CB_backup {
    ((t = SECONDS))
    DATE=$(date "+%F")
    umask 0007
    mysqldump --opt ipb > /tmp/ipb.sql
    xz /tmp/ipb.sql
    chown www-data:www-data /tmp/ipb.sql.xz
    mv {/tmp/ipb,/backups/sql-backups/$DATE}.sql.xz
    logInfo "$(date -u) SQL backup completed in $((SECONDS-t)) secs"
}
