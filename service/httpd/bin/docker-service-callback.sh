#! /bin/bash

# Service callbacks for service httpd

# check if a separate callback is handling the call
[ -f /usr/local/sbin/service-$1 ] && exec /usr/local/sbin/service-$1 "$@"

case $1 in

  flushlogs)
    kill  -s USR1  1  ;;

  certbot)
    # If the current certificate is older than ~2 months, then create a certbot HTTP-01 
    # challenge response directory, run certbot and clean up

    OLDCERT=$(find /etc/letsencrypt/live/forum.buildhub.org.uk/fullchain.pem -mtime +61)
    if [ -n "$OLDCERT" ]; then
      echo "$(date -u) Checking / Renewing *.buildhub.org.uk certificates" > /proc/1/fd/1
      mkdir /var/www/acme; chown www-data:www-data /var/www/acme
      certbot certonly -n -d forum.buildhub.org.uk,www.buildhub.org.uk,test.buildhub.org.uk \
                       --webroot -w /var/www/acme > /proc/1/fd/1  2>&1
      rm -rf /var/www/acme
    else
      echo "$(date -u) Skipping certificate renewal" > /proc/1/fd/1
    fi  ;;

  *) ;;
esac
