#! /bin/bash
function entry_setup() {
  cp conf/crontab /etc/crontab
   
  #  For simplicity the /var/log directory is shared between all services so all the
  #  log rotation is done as part of housekeeping, and all config is in the base 
  #  logrotate.conf. All logrotate.d entries are removed to avoid confusion.
  
  cp conf/logrotate.conf /etc
  rm -f /etc/logrotate.d/*
} 
. /etc/docker-entry-helper --parent cron "-f -L 7"
