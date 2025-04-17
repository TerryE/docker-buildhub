#!/usr/bin/env python3
# Cloud-upload.py
import re
import os
import sys
from datetime import datetime
from webdav3.client import Client

# Configuration
NETRC = os.path.expanduser("~/.netrc")
DIRS = {
    '/backups/backups': "public/tar-backups",
    '/backups/sql-backups': "public/sql-backups",
}
DEBUG = '--debug' in sys.argv

def log(msg):
    print(datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ' - ' + msg, flush=True)

def debug(msg):
    if DEBUG: log(f"DEBUG: {msg}")

def connect_webdav():
    """Connect to WebDAV with .netrc credentials"""
    settings = {}
    with open(NETRC, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                settings[parts[0]] = parts[1]
    
    required = ['machine', 'login', 'password']
    if any(key not in settings for key in required):
        log("ERROR: Missing .netrc credentials")
        sys.exit(1)
    
    return Client({
        'webdav_hostname': f"https://{settings['machine']}",
        'webdav_login': settings['login'],
        'webdav_password': settings['password'],
    })
def sync_files(client):
    """Sync files matching pattern to remote"""
    pattern = re.compile(r'^([\w\-]+?)-([0-9a-f]{32})\.(.*)$')
    
    for local_dir, remote_dir in DIRS.items():
        log(f"Syncing {local_dir} to {remote_dir}")
        client.mkdir(remote_dir)  # Ensure exists
        
        remote_files = set(client.list(remote_dir))
        debug(f"Remote files: {remote_files}")
        
        for filename in os.listdir(local_dir):
            local_path = os.path.join(local_dir, filename)
            if not (pattern.match(filename) and os.path.isfile(local_path)):
                debug(f"Skipping {filename} (invalid)")
                continue
            
            if filename in remote_files:
                debug(f"Skipping {filename} (exists)")
                continue
            
            remote_path = f"{remote_dir}/{filename}"
            client.upload_file(remote_path, local_path)
            log(f"Uploaded {filename}")

def main():
    log("Starting sync")
    try:
        client = connect_webdav()
        sync_files(client)
        log("Sync complete")
    except Exception as e:
        log(f"FATAL: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
