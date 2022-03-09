#! /bin/bash

# Service callbacks for service redis

# check if a separate callback is handling the call
[ -f /usr/local/sbin/service-$1 ] && exec /usr/local/sbin/service-$1 "$@"

case $1 in

  # Service redis currently doesn't implement any callback, so this is a placeholder

  *) ;;
esac
