#!/bin/bash

declare DTS=$(date -u)

function logInfo  { echo "$DTS Listener Info: $1"; }
function logError { echo "$DTS Listener Error: $1"; exit 1; }
function errorHandler { local line_no="$1" cmd="$2" status="$?"
    logError "in line $line_no: exit code $status: while executing command $cmd"
}
set -Eeuo pipefail
trap 'errorHandler $LINENO "$BASH_COMMAND"' ERR

function runCB {
    # #runCB someAction will run the function CB_someAction if it has been defined
    #  in the docker-callback-function.sh sourced next
    local ACTION="$2"
    local _v="CB_$1"; local -F $_v &>/dev/null || logError "No action '$ACTION' defined";
    shift; $_v $*
}

# Generate the logrotate conf file for this container

function rotateLogs {
    #
    # Pretty much all services that log to /var/log are handled the same hence the long COMMON
    # set. Most services play nicely and accept a USR1 signal to flush and rotate logs,  The easiest
    # way doing this is to signal tini (PID 1) and this forwards it.  redis-server is the exception
    #
    COMMON='weekly:rotate 4:create:compress:missingok:notifempty:delaycompress:sharedscripts:minsize 1M'
    FLUSH='postrotate:kill -USR1 1:endscript'
    local -A logMap=(
      [apache2]='maxsize 50M:dateext:FLUSH'
      [mysql]='su mysql mysql:maxsize 5M:FLUSH'
      [php]='maxsize 5M:FLUSH'
      [redis]='su redis redis:monthly')
    HOST=$(hostname)
    RULES="${logMap[$HOST]}"
    [[ -z $RULES ]] && return 1  # Don't rotate if there is no logMap entry

    RULES="${RULES/%FLUSH/$FLUSH}"
    RULES="${COMMON}:/var/log/$HOST/*.log{:$RULES:}"
    logInfo "logrotate $RULES"
    echo "$RULES" | sed 's/:/\n/g'> /tmp/$$.conf
    logrotate /tmp/$$.conf
    rm /tmp/$$.conf
}

source /usr/local/bin/docker-callbacks.sh

while read -r user action; do
    DTS=$(date -u)
    callbackFn="CB_${action//-/_}"
    if [[ $(type -t "$callbackFn") == "function" ]]; then
    	logInfo "Running $action for $user"
        # The CB_<action> must use setpriv to drop uid if necessary
        $callbackFn $user
    else
        logInfo "Unknown action: $action"
    fi
done

# vim: autoindent expandtab tabstop=4 shiftwidth=4
