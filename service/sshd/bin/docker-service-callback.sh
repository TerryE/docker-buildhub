#! /bin/bash

# Service callbacks for service sshd

# check if a separate callback is handling the call
[ -f /usr/local/sbin/service-$1 ] && exec /usr/local/sbin/service-$1 "$@"

case $1 in

  flushlogs)
    kill  -s USR1  1  ;;

  *) ;;
esac
