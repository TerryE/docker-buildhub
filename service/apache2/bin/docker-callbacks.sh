
function CB_rotate_logs { rotateLogs; }

function CB_certbot_check {

    # If the current certificate is older than ~2 months, then create a certbot HTTP-01
    # challenge response directory, run certbot and clean up
    OLDCERT=$(find /etc/letsencrypt/live/forum.${DOMAIN}/fullchain.pem -mtime -61)
    [[ -n $OLDCERT ]] && ( echo "$(date -u) Skipping certificate renewal"; return; )
      
    echo "$(date -u) Checking / Renewing *.${DOMAIN} certificates"
    mkdir /var/www/acme; chown www-data:www-data /var/www/acme
    certbot certonly -n -d forum.${DOMAIN},www.${DOMAIN},test.${DOMAIN} \
                     --webroot -w /var/www/acme
    rm -rf /var/www/acme
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

function CB_sitemap_gen { USR="$1"
    # Task can take a long time to run so skip if bash is already running. Do
    # this by doing ps -C bash. This should count 2 (this bash + 'ps -C bash')
    TASK_PHP="/usr/local/sbin/generate-sitemaps.php"
    TASK_CMD="php $TASK_PHP -F"
    [[ $USR != 'root' ]] && \
        SETPRIV="exec setpriv --reuid=$USR --regid=$USR --init-groups --"
    $SETPRIV $TASK_CMD
}

function CB_sitemap_txt_gen { USR="$1"
    # Skip if a previous run is still going (ps -C bash should be 2: this + 'ps -C bash')
    NBASH=$(ps --no-headers -C bash -o pid | wc -l)
    [[ $NBASH -gt 2 ]] && return
    TASK_PHP="/usr/local/sbin/generate-sitemap-txt.php"
    # Script reads DB creds from conf_global.php (path passed via env)
    export BUILDHUB_CONF_GLOBAL="/var/www/ipb/conf_global.php"
    TASK_CMD="php $TASK_PHP"
    [[ $USR != 'root' ]] && \
        SETPRIV="exec setpriv --reuid=$USR --regid=$USR --init-groups --"
    $SETPRIV $TASK_CMD
}
