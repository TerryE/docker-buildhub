#! /bin/bash
pipe=/run/host-callback/app.pipe
[[ -p $pipe ]] && [[ -n "$VHOST" ]] && echo ${VHOST} "$1" "$2" >> $pipe
