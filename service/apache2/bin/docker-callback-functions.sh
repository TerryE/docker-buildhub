
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

function CB_nightly_backup { USR=$1
    [[ "$VHOST" == "forum" ]] || exit   # backups are only carried out on the live forum
set -vx
    umask 0007
    local DATE=$(date +%F)  LEVEL=2   TYPE="daily"
    if [[ "$DATE.X" =~ "-01.X" ]]; then  LEVEL=1  TYPE="monthly"; fi
    local SNAR=backups/ipb-level${LEVEL}.snar

    cd /backups
    cp -p ${SNAR}{,_old}

    TAR_FILES="--file=backups/${DATE}-var_www-${TYPE}.tar --listed-incremental=$SNAR" 
    TAR_CMD="tar --create --anchored  --directory=/var/www $TAR_FILES --exclude ipb/datastore/* ipb"
    setpriv --reuid=$USR --regid=$USR --init-groups -- $TAR_CMD

    [[ "$LEVEL" == "1" ]] && cp -p  backups/ipb-level{1,2}.snar
}
