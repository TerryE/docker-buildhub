
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

    umask 0007

    local DATE=$(date +%F)  LEVEL=2   TYPE="daily"
    if [[ "$DATE.X" =~ "-01.X" ]]; then  LEVEL=1  TYPE="monthly"; fi

    local SNAR="ipb-level${LEVEL}"
    local TARBALL="www-${TYPE}-${DATE}"
    local TAR_FILES="--file=$TARBALL.tar --listed-incremental=$SNAR.snar" 
    local TAR_CMD="tar --create --anchored  --directory=/var/www $TAR_FILES --exclude ipb/datastore/* ipb"
    
    cd /backups/backups
    # Create new tarball and SNARfile as user $USR
    setpriv --reuid=$USR --regid=$USR --init-groups -- $TAR_CMD

    local MD5=$(md5sum $TARBALL.tar)
    mv $TARBALL.tar "$TARBALL-${MD5%% *}.tar" 

    MD5=$(md5sum $SNAR.snar)
    cp --preserve=all $SNAR.snar "$SNAR-${MD5%% *}.snar"
   
    # One the first of the month, the level 1 SNAR must be copied to the level 2 for the 2nd's daily incremental
    [[ "$LEVEL" == "2" ]] || cp -p  backups/ipb-level{1,2}.snar
}
