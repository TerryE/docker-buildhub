
SERVICE=scheduler
COMMAND=scheduler.py
SCRIPT_PATH="/usr/local/bin/$COMMAND"
REUID=$(stat -c "%u" "$SCRIPT_PATH")
REGID=$(stat -c "%g" "$SCRIPT_PATH")

