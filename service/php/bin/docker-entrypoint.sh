#! /bin/bash

echo "$(date -u) Entering PHP startup" > /proc/1/fd/1
#                ====================

PHPVER=${PHP_VERSION#php}

ln -sfT /var/log/php{$PHPVER,}
[ -d /var/log/php$PHPVER ] || mkdir /var/log/php$PHPVER # Make log dir if needed

# Alpine uses PHP_VERSION as the command root, so symlink the corresponding php aliases

for d in /etc /usr/bin /usr/lib /usr/include /var/log; do ln -sfT $d/php{$PHPVER,}; done 
ln -sfT /usr/sbin/php-fpm{$PHPVER,}

#  These are the PHP ini settings that need changing

sed -i '/^disable_functions/s/=.*/=  "exec,system,passthru,popen,proc_open,shell_exec"/
        /^expose_php/s/=.*/= Off/
        /^memory_limit/s/=.*/= 256M/
        /;html_errors/s/^.*/html_errors = Off/
        /session.cookie_samesite/s/=.*/= On/' /etc/php/php.ini
        
sed -i '/error_log =/s!.*!error_log = /var/log/php/error.log!
        /daemonize =/s!.*!daemonize = no!'    /etc/php/php-fpm.conf

# Copy php-fpm.d configs to /etc/php/php-fpm.d/

cp  /usr/local/conf/* /etc/php/php-fpm.d/

# The logrotate done by housekeeping

rm -f /etc/logrotate.d/*

echo "$(date -u) PHP startup: starting php-fpm service" > /proc/1/fd/1
#                =====================================

# if the first arg is present but not an option then exec it, otherwise append to php-fpm
[ -n "$1" ] && [ "${1#-}" == "$1" ] && exec "$@"
exec tini php-fpm -F "$@"
