#!/bin/bash
function entry_setup() {
  # Copy any local conf files into the MySQL conf.d folder to be scanned on startup
  cp /usr/local/conf/* /etc/mysql/conf.d/
  
  mkdir -p /var/lib/mysql
  mkdir -p /run/mysqld
  chown -R mysql:mysql /var/lib/mysql
  chown -R mysql:mysql /run/mysqld
}
. /etc/docker-entry-helper mariadbd "--datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock"
