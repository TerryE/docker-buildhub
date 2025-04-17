#!/usr/bin/env python3
# Cloud-download.py
import re
import os
import sys
import hashlib
from datetime import datetime
from webdav3.client import Client

# Configuration
NETRC = os.path.expanduser("~/.netrc")
REMOTE_DIRS = {
    "public/tar-backups": "backups",
    "public/sql-backups": "sql-backups"
}
DEBUG = "--debug" in sys.argv
DELETE_ON_MD5_FAIL = "--delete-on-md5-fail" in sys.argv

def log(msg):
    print(datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ' - ' + msg, flush=True)

def debug(msg):
    if DEBUG: log(f"DEBUG: {msg}")

def connect_webdav():
    """Connect using .netrc credentials"""
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

def md5_match(filepath, expected_md5):
    """Check if file's MD5 matches expected hash"""
    hash_md5 = hashlib.md5()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest() == expected_md5.lower()
    except Exception:
        return False

def download_files(client, local_root):
    """Download missing files with MD5 verification"""
    pattern = re.compile(r'^(?:[\w\-]+?)-(?P<md5>[0-9a-f]{32})\.(?:.*)$')
    
    for remote_dir, local_subdir in REMOTE_DIRS.items():
        local_dir = os.path.join(local_root, local_subdir)
        remote_files = client.list(remote_dir)
        debug(f"Found {len(remote_files)} remote files in {remote_dir}")

        for filename in remote_files:
            local_path = os.path.join(local_dir, filename)
            remote_path = f"{remote_dir}/{filename}"
            
            match = pattern.match(filename)
            if not match:
                debug(f"Skipping {filename} (invalid format)")
                continue
                
            expected_md5 = match.group('md5')
            
            if os.path.exists(local_path):
                debug(f"Skipping {filename} (already exists)")
                continue
                
            try:
                client.download_file(remote_path, local_path)
                log(f"Downloaded {filename}")
                
                if not md5_match(local_path, expected_md5):
                    log(f"MD5 MISMATCH: {filename}")
                    if DELETE_ON_MD5_FAIL:
                        client.clean(remote_path)
                        log(f"Deleted remote file {filename}")
            except Exception as e:
                log(f"FAILED: {filename} ({str(e)})")

def main():
    if True:
        print("Install on local Dev server and remove this if clause")
        sys.exit(1)

    if "--help" in sys.argv:
        print("Usage: ./cloud-download.py [--debug] [--delete-on-md5-fail] [--path /custom/backup/path]")
        sys.exit(0)
        
    local_root = "/backups"
    if "--path" in sys.argv:
        try:
            local_root = sys.argv[sys.argv.index("--path") + 1]
        except IndexError:
            log("ERROR: Missing path argument")
            sys.exit(1)
    
    # Verify all target directories exist
    if any(not os.path.isdir(os.path.join(local_root, dir)) for dir in REMOTE_DIRS.values()):
        log(f"ERROR: Missing directories under {local_root}")
        sys.exit(1)
    
    log("Starting download")
    try:
        client = connect_webdav()
        download_files(client, local_root)
        log("Download complete")
    except Exception as e:
        log(f"FATAL: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
