
function setupErrorHandling {
    # The -Ee options are really useful for trapping errors, but the downside it that the script
    # must explicitly handle cases where a 1 status is valid, e.g. by adding a "|| :" pipe.
    set -Eeuo pipefail
    trap 'errorHandler $LINENO "$BASH_COMMAND"' ERR
    function errorHandler {
        local line_no="$1" cmd="$2" status="$?"
        local error_message="✗ error in line $line_no: exit code $status: while executing command $cmd"
        echo -e "\n$error_message\n"
    }
    function logInfo  { echo "Callback(Info): $1"; }
    function logError { echo "Callback(Error): $1"; exit 1; }
    function logOK    { echo "Callback: $1"; }
}

function runCB {
    # #runCB someAction will run the function CB_someAction if it has been defined
    #  in the docker-callback-function.sh sourced next
    local _v=_$1; local -F $_v &>/dev/null || logError "No action '$ACTION' defined";
    shift; $_v $*
}

source /usr/bin/local/docker-callback-functions.sh

# Generate the logrotate conf file for this container

function lotateLogs {
    #
    # Pretty much all services that log to /var/log are handled the same hence the long COMMON
    # set. Most services play nicely and accept a USR1 signal to flush and rotate logs,  The easiest
    # way doing this is to signal tini (PID 1) and this forwards it.  redis-server is the exception
    #
    COMMON='weekly:rotate 4:create:compress:missingok:notifempty:delaycompress:sharedscripts:minsize 1M"
    FLUSH='postrotate:kill -USR1 1:endscript'
    local -A logMap=(
      [apache2]='maxsize 50M:FLUSH',
      [mysql]='maxsize 5M:FLUSH',
      [php]='maxsize 5M:FLUSH',
      [redis]='monthly')

    HOST=$(hostname)`
    RULES=${logMap[$HOST]}

    [[ -z $RULES ]] && return 1  # Don't rotate if there is no logMap entry
    echo "${COMMON}:/var/log/$HOST/*.log{${RULES/%FLUSH/$FLUSH}}" | sed 's/:/\n/g' > /tmp/$$.conf
    logrotate /tmp/$$.conf
#   rm /tmp/$$.conf
}

# =================================== Effective Main Entry =====================================

function _main_ { ACTION="$1"
    
    setupErrorHandling
    
    # This script has run as root, and redirect output to docker logger,  but fail silenty if not

    [[ "$(groups)" =~ "root" ]] || exit
    # exec 1>/proc/1/fd/1 2>&1

    source /usr/bin/local/docker-callback-functions.sh

    rubCB "$ACTION"
}

_main_ $@
# vim: autoindent expandtab tabstop=4 shiftwidth=4
