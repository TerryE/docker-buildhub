#! /bin/bash
#
# This the standard Docker entry script for all containers
#
set -evx

source /usr/local/bin/docker-entry-setup.sh

echo "$(date -u) Entering ${SERVICE} startup"

# Directories used by service
SOCKDIR="/run/${SERVICE}"
LOGDIR="/var/log/${SERVICE}"

[[ -n ${RUNMODE} ]]              && RUNMODE="-m ${RUNMODE}"
[[ -n ${USER}  && -z ${GROUP} ]] && GROUP="$USER"
[[ -n ${REUID} && -z ${REGID} ]] && REGID="${REUID}"

# Create the SOCKDIR and LOGDIR directories with the correct ownership, if needed
[[ -n ${USE_RUNSOCK} ]] \
  && ( mkdir -p ${RUNMODE} "${SOCKDIR}"; chown "${USER}":"${GROUP}" "${SOCKDIR}"; )
[[ -n ${USE_VARLOG} ]] \
  && ( mkdir -p            "${LOGDIR}";  chown "${USER}":"${GROUP}" "${LOGDIR}"; )

# If REUID is defined then build the setpriv command preamble
[[ -n ${REUID} ]] \
  && SETPRIV="setpriv --reuid=${REUID} --regid=${REGID} --init-groups --"

echo "$(date -u) Initiating ${SERVICE}"

exec ${SETPRIV} ${COMMAND} ${OPTS}
