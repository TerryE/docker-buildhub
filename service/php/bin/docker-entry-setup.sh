
SERVICE=php
USER=forum
USE_RUNSOCK=true
USE_VARLOG=true
COMMAND=/usr/sbin/php-fpm$PHP_VERSION
#  PHP_VERSION as the command root, so symlink the log dir alias
ln -sfT /var/log/php{,$PHP_VERSION}
ln -sfT /var/log/php{,-fpm}

#  To eep things simple: both CLI and FPM core setting the same
rm -Rf /etc/php/$PHP_VERSION/cli/{php.ini,conf.d}
ln -sfT /etc/php/$PHP_VERSION/{fpm,cli}/conf.d
ln -sfT /etc/php/$PHP_VERSION/{fpm,cli}/php.ini

#  These are the PHP ini settings that need changing
cat > /etc/php/$PHP_VERSION/fpm/conf.d/99-custom.ini <<-EOC
	[PHP]
	disable_functions = "exec,system,passthru,popen,proc_open,shell_exec"
	expose_php = Off
	memory_limit = 256M
	html_errors = Off
	[Session]
	session.cookie_samesite = On
EOC

cp  /usr/local/conf/* /etc/php/$PHP_VERSION/fpm/pool.d/
