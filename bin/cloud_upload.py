#!/usr/bin/env python3
#  Cloud-upload.py
import re
import os
import sys
import hashlib
from datetime import datetime
from webdav3.client import Client

# Configuration
NETRC = os.path.expanduser("~/.netrc")
DIRS = {
    '/backups/backups':      "public/tar-backups",
    '/backups/sql-backups': "public/sql-backups",
}

def info(msg):
    print(datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ' - ' + msg + "\n", flush = True)

def connect_to_webdav_using_netrc():
    settings = {}
    with open(NETRC, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                settings[parts[0]] = parts[1]
    for key in ['machine', 'login', 'password']:
        if key not in settings:
            raise ValueError(f"Missing required key '{key}' in .netrc")
    return Client({
        'webdav_hostname': f"https://{settings['machine']}",
        'webdav_login': settings['login'],
        'webdav_password': settings['password'],
    })

# Rename and upload files
def process_files(client):
    r = re.compile(r'^([\w\-]+?)-([0-9a-f]{32})\.(.*)$')
    for local_dir, remote_dir in DIRS.items():
        info(f'Processing {local_dir}')
        remote_files = set(client.list(remote_dir))
        for filename in os.listdir(local_dir):
            local_file = f'{local_dir}/{filename}'
            # info(f'Checking file {filename}')
            if all([
                r.match(filename),
                not filename in remote_files,
                os.path.isfile(local_file)
                ]):
                remote_file = f'{remote_dir}/{filename}'
                client.upload_file(remote_file, local_file)
                info(f'{local_dir}/{filename} copied to {remote_dir}')

def main():
    info("Starting backup sync")
    client = connect_to_webdav_using_netrc()

    # Process backup tarballs
    process_files(client)
    info(f"Backup sync complete")

if __name__ == "__main__":
    main()

