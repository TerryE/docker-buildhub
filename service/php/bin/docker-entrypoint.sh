#! /bin/bash
function entry_setup() {
  local VER="$PHP_VERSION"
set -vx
  #  PHP_VERSION as the command root, so symlink the log dir alias
  [[ -d  /var/log/php ]] || mkdir -p /var/log/php
  [[ -d  /var/log/php-fpm ]] && rm -R /var/log/php-fpm
  [[ -d  /var/log/php ]] || mkdir -p /var/log/php
  ln -sfT /var/log/php{,$VER}
  ln -sfT /var/log/php{,-fpm}

  #  Keep things simple: both CLI and FPM core setting the same
  rm -Rf /etc/php/$VER/cli/{php.ini,conf.d}
  ln -sfT /etc/php/$VER/{fpm,cli}/conf.d
  ln -sfT /etc/php/$VER/{fpm,cli}/php.ini
  
  #  These are the PHP ini settings that need changing
  
  sed -i '/^disable_functions/s/=.*/=  "exec,system,passthru,popen,proc_open,shell_exec"/
          /^expose_php/s/=.*/= Off/
          /^memory_limit/s/=.*/= 256M/
          /;html_errors/s/^.*/html_errors = Off/
          /session.cookie_samesite/s/=.*/= On/' /etc/php/$VER/fpm/php.ini
          
  sed -i '/error_log =/s!.*!error_log = /var/log/php/error.log!
          /daemonize =/s!.*!daemonize = no!'    /etc/php/$VER/fpm/php-fpm.conf
  
  # Copy php-fpm.d configs to /etc/php/php-fpm.d/
  
  cp  /usr/local/conf/* //etc/php/$VER/fpm/pool.d/
  
  mkdir -p /run/php
}
. /etc/docker-entry-helper --parent php-fpm$VER "-F"
