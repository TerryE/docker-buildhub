#!/usr/bin/env python3
# scheduler.py
import re
import schedule
import time
import os
import logging
import sys
import socket
from pathlib import Path

# Configuration
SCHEDULE_FILE  = "/usr/local/conf/schedule.cron"
TIME_PATTERN   = re.compile(r'^(\*|/([1-9]\d?)|([0-5]?\d))$')
ENTITY_PATTERN = re.compile(r'^[a-z0-9]+$')
ACTION_PATTERN = re.compile(r'^[a-z0-9][a-z0-9-]*$')

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stderr)],
)
logger = logging.getLogger(__name__)

def send_request(service, action, user="root"):
    """Fire-and-forget socket delivery"""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.connect(f"/run/{service}-request.sock")
            sock.sendall(f"{user} {action}".encode())
        logger.debug(f"Sent to {service}: {user} {action}")
    except Exception as e:
        logger.warning(f"Delivery of {user} {action} failed to {service}: {str(e)}")

def parse_cron_line(line):
    """Strict cron line parsing with regex validation"""
    parts = line.strip().split()
    if len(parts) not in (7, 8):
        raise ValueError(f"Expected 7-8 fields, got {len(parts)}")

    min, hr, dom, mon, dow = parts[:5]
    user = parts[5] if len(parts) == 8 else 'root'
    service, action = parts[-2:]

    # Validate interval syntax rules
    if min.startswith("/") and hr != "*":
        raise ValueError("When using /n minutes, hours must be *")
    if hr.startswith("/") and min != "*":
        raise ValueError("When using /n hours, minutes must be *")

    # Field format validation
    checks = [
        bool(TIME_PATTERN.match(min)),
        bool(TIME_PATTERN.match(hr)),
        (dom == '*' and mon == '*' and dow == '*'),
        bool(ENTITY_PATTERN.match(user)),
        bool(ENTITY_PATTERN.match(service)),
        bool(ACTION_PATTERN.match(action))
    ]

    if not all(checks):
        raise ValueError("Invalid field syntax")

    return {
        'min': min,
        'hr': hr,
        'user': user,
        'service': service,
        'action': action
    }

def load_schedules():
    """Load and validate schedule file"""
    schedules = []
    try:
        with open(SCHEDULE_FILE) as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if line and not line.startswith("#"):
                    try:
                        schedules.append(parse_cron_line(line))
                    except ValueError as e:
                        logger.error(f"Line {line_num}: {str(e)}")
        return schedules
    except FileNotFoundError:
        logger.critical(f"Missing schedule file: {SCHEDULE_FILE}")
        sys.exit(1)

def setup_jobs(schedules):
    """Configure scheduled jobs with interval validation"""
    for job in schedules:
        task = lambda user=job['user'], svc=job['service'], act=job['action']: \
               send_request(svc, act, user)
        msg = f"→ {job['user']} {job['service']} {job['action']}"

        if job['min'].startswith("/"):
            interval = int(job['min'][1:])
            logger.info(f"Every {interval:2} min   {msg}")
            schedule.every(interval).minutes.do(task)
        elif job['hr'].startswith("/"):
            interval = int(job['hr'][1:])
            logger.info(f"Every {interval:2} hours {msg}")
            schedule.every().hour.at(f":{mm:02d}").do(task)
        else:
            mm = 0 if job['min'] == '*' else  int(job['min'])
            hh = 0 if job['hr']  == '*' else  int(job['hr'])
            hhmm = f"{hh:02d}:{mm:02d}"
            logger.info(f"Daily at {hhmm} {msg}")
            schedule.every().day.at(f"{hhmm}").do(task)

if __name__ == "__main__":
    try:
        setup_jobs(load_schedules())
        logger.info("Scheduler started")
        while True:
            schedule.run_pending()
            time.sleep(60)
    except KeyboardInterrupt:
        logger.info("Scheduler stopped by user")
    except Exception as e:
        logger.critical(f"Fatal error: {str(e)}")
        sys.exit(1)
