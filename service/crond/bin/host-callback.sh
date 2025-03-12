#! /bin/bash
#
# /run/host-callback is mapped to a host directory. The call-back listener creates a pipe in
# this directory and monitors this pipe for callback commands.  If this pipe hasn't been
# created yet, then ignore the command otherwise route it via the call-back pipe.
#
PIPE=/run/host-callback/call-back.pipe
if [[ -p $PIPE ]]; then
    [[ -n "$VHOST" ]] && echo ${VHOST} "$1" "$2" >> $PIPE
fi
