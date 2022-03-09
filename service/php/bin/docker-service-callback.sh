#! /bin/bash

# Service callbacks for service php

# check if a separate callback is handling the call
[ -f /usr/local/sbin/service-$1 ] && exec /usr/local/sbin/service-$1 "$@"

case $1 in
  task)
    TASK_KEY=$(cd /var/www/ipb; php <<-'EOD' 2>/dev/null)
      <?php
      require \'conf_global.php\'; extract($INFO);
      $p   = intval($sql_port);
      $sql = "select conf_value from core_sys_conf_settings where conf_key=\'task_cron_key\'";
      $db  = new mysqli( $sql_host, $sql_user, $sql_pass, $sql_database, $p, NULL);
      echo $db->query($sql)->fetch_row()[0];
EOD
    [ -n "$TASK_KEY" ] && php -d memory_limit=-1 -d max_execution_time=0 \
                          applications/core/interface/task/task.php $TASK_KEY ;;

  *) ;;
esac
