#! /bin/bash

# This the standard Docker entry script for all containers
#exec 1>/proc/1/fd/1 2&>1
set -evx

source /usr/local/bin/docker-entry-setup.sh
echo "$(date -u) Entering $SERVICE startup" > /proc/1/fd/1
[[ -n $USER && -z $GROUP ]] && GROUP="$USER"
[[ -n $RUNMODE ]] && RUNMODE="-m $RUNMODE"
[[ -n $USE_RUNSOCK ]] && ( mkdir -p $RUNMODE /run/$SERVICE; chown $USER:$GROUP /run/$SERVICE; ) 
[[ -n $USE_VARLOG ]] && ( mkdir -p /var/log/$SERVICE; chown $USER:$GROUP /var/log/$SERVICE; ) 

[[ -n $REUID && -z $REGID ]] && REGID="$REUID"
[[ -n $REUID ]] && SETPRIV="setpriv --reuid=$REUID --regid=$REGID --init-groups --"

echo "$(date -u) Initiating $SERVICE with tini" > /proc/1/fd/1

exec $SETPRIV tini $TINI_OPTS $COMMAND -- $OPTS
