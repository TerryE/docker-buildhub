#! /bin/bash
#
#  These are the PHP ini settings that need changing
#
echo "$(date -u) Entering PHP config hook" > /proc/1/fd/1
ln -sfT /var/log/php{,8}
ln -sfT /var/log/php{,-fpm}

sed -i '/^disable_functions/s/=.*/=  "exec,system,passthru,popen,proc_open,shell_exec"/
        /^expose_php/s/=.*/= Off/
        /;html_errors/s/^.*/html_errors = Off/
        /session.cookie_samesite/s/=.*/= On/' /etc/php/php.ini

sed -i '/error_log =/s!.*!error_log = /var/log/php/error.log!
        /daemonize =/s!.*!daemonize = no!' /etc/php/php-fpm.conf
        
cp  {/usr/local/conf,/etc/php}/php-fpm.d/www.conf

echo "$(date -u) PHP config updated" > /proc/1/fd/1
