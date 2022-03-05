#! /bin/bash
#
# Service callbacks for all containers

[ -f /usr/local/$HOSTNAME/bin ] && export PATH=/usr/local/$HOSTNAME/bin;$PATH

if [ -f /usr/local/$HOSTNAME/bin/service-$1 ]; then 
  exec /usr/local/$HOSTNAME/bin/service-$1 "$@";

elif [ -f /usr/local/$HOSTNAME/bin/service-$1 ]; then 
  exec /usr/local/$HOSTNAME/bin/service-$1 "$@";

elif [ "$1" == "restart" ]; then
  case "$HOSTNAME" in
      apache2)   kill  -USR1  1         ;;
      mysql)     mysqladmin flush-logs  ;;
      php)       kill  -USR1  1         ;;
      redis|hk)                         ;;
  esac
#  ==== anything else is ignored =====
fi
