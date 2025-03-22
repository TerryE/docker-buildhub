
function CB_rotate_logs { rotateLogs; }

function CB_task_check { USR="$1"
    # Task can take a long time to run so skip if bash is already running. Do
    # this by doing ps -C bash. This should count 2 (this bash + 'ps -C bash')
    NBASH=$(ps --no-headers  -C bash -o pid | wc -l)
    TASK_KEY="$(cat /run/secrets/forum-token)"
    [[ $NBASH -gt 2 || -z $TASK_KEY ]] && return 
    TASK_PHP='/var/www/ipb/applications/core/interface/task/task.php'
    TASK_CMD="php -d memory_limit=-1 -d max_execution_time=0 $TASK_PHP $TASK_KEY"
    [[ $USR != 'root' ]] && \
        SETPRIV="exec setpriv --reuid=$USR --regid=$USR --init-groups --"
    $SETPRIV $TASK_CMD
}
