#!/usr/bin/env python3

import docker
import schedule
import time
import os
import logging
import sys

# Configuration
VHOST = os.environ.get("VHOST")  # Get project name from environment
SCHEDULE_FILE = "/usr/local/conf/schedule.cron"
CALLBACK_SCRIPT = "docker-callback.sh"

client = docker.from_env()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stderr)],
)

logger = logging.getLogger(__name__)

def remoteExec(service, action, user):
    """Execute a command in another Docker container."""
    name = f"{VHOST}_{service}"
    try:
        logger.info(f"Starting '{action}' in {name} (user: {user})")
        container = client.containers.get(name)
        exec_command = ["bash", "sbin/docker-callback.sh", user, action]
        container.exec_run(exec_command, stdout=False, stderr=False, detach=True)
        logger.info(f"Executed '{action}' in {name} (user: {user})")
        
    except docker.errors.NotFound:
        logger.info(f"Container {name} not found. Skipping execution.")
    except docker.errors.APIError as e:
        logger.exception(f"APIError executing '{action}' in {name}: {e}")
    except Exception as e:
        logger.exception(f"Unexpected error executing '{action}' in {name}: {e}")

def parse_cron_line(line, remote_exec_func):
    parts = line.split()

    min, hr, dom, mon, dow = parts[:5]
    user = parts[5] if len(parts) == 8 else 'root'
    service, action = parts[-2:]

    if len(parts) < 7 or dom != '*' or mon != '*' or dow != '*':
        raise Exception(f"Invalid schedule line: {line}")
    
    def do_task(period):
        period.do(remote_exec_func, service=service, action=action, user=user)
    
    def log(at):
        logger.info(f"{at:<17} {user:<9} {service:<10} {action}")
        
    if min.startswith("/") and hr == '*':         # every n mins
        log(f"every {int(min[1:])} mins")
        do_task(schedule.every(int(min[1:])).minutes)
    elif hr.startswith("/") and min == '*':      # every n hrs
        log(f"every {int(hr[1:])} hours")
        do_task(schedule.every(int(hr[1:])).hours)
    else:
        mm = -1 if min == '*' else int(min)
        hh = -1 if hr == '*' else int(hr)
        if mm >= 0 and hh < 0:                        # at mm mins after each hr
            log(f"hourly at **:{mm:02d}")
            do_task(schedule.every().hour.at(f":{mm:02d}"))
        elif mm < 0 and hh >= 0:                      # at hh hrs after each day
            log(f"daily at {hh:02d}:00")
            do_task(schedule.every().day.at(f"{hh:02d}:00"))
        elif mm >= 0 and hh >= 0:                     # every hh:mm each day
            log(f"daily at {hh:02d}:{mm:02d}")
            do_task(schedule.every().day.at(f"{hh:02d}:{mm:02d}"))
        else:
            raise Exception(f"Invalid schedule line: {line}")

def load_schedule_from_file(filename, remote_exec_func):
    """Loads and parse cron-like lines from a file."""
    try:
        with open(filename, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):  # Ignore comments and empty lines
                    parse_cron_line(line, remote_exec_func)
    except FileNotFoundError:
        raise Exception(f"Schedule file {filename} not found.")
    except Exception as e:
        raise Exception(f"Error loading schedule file: {e}")

if __name__ == "__main__":
    try:
        load_schedule_from_file(SCHEDULE_FILE, remoteExec)
        while True:
            schedule.run_pending()
            time.sleep(60)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
