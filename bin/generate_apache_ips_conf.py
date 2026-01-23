#!/bin/env python3
import requests
import argparse
import sys
import os

# The three "High Trust" Google service feeds
URLS = [
    "https://developers.google.com/search/apis/ipranges/googlebot.json",
    "https://developers.google.com/search/apis/ipranges/special-crawlers.json",
    "https://developers.google.com/search/apis/ipranges/user-triggered-fetchers-google.json"
]

def get_google_ips():
    """Fetches and returns a sorted list of Apache 'Require ip' strings."""
    ip_list = set() # Use a set to automatically handle any duplicates across feeds
    
    for url in URLS:
        try:
            r = requests.get(url, timeout=10)
            r.raise_for_status()
            data = r.json()
            for entry in data['prefixes']:
                ip = entry.get('ipv4Prefix') or entry.get('ipv6Prefix')
                if ip:
                    ip_list.add(f"Require ip {ip}")
        except Exception as e:
            print(f"Error: Failed to process {url}: {e}", file=sys.stderr)
            sys.exit(1)
            
    return sorted(list(ip_list))

def update_if_changed(output_path):
    # 1. Generate the new content
    new_ips = get_google_ips()
    new_content_lines = [
        "# Auto-generated Google Allowlist",
        f"# Total unique ranges: {len(new_ips)}"
    ] + new_ips
    
    # 2. Read existing content
    existing_content = []
    if os.path.exists(output_path):
        with open(output_path, "r") as f:
            # Strip whitespace/newlines for a clean comparison
            existing_content = [line.strip() for line in f.readlines() if line.strip()]

    # 3. Compare (stripping whitespace from new content for the check)
    if new_content_lines == existing_content:
        print("No changes detected. File was not overwritten.")
        sys.exit(0) # Exit with 0, but no action taken
    
    # 4. Write if different
    try:
        with open(output_path, "w") as f:
            f.write("\n".join(new_content_lines) + "\n")
        print(f"Changes detected. Updated {output_path} with {len(new_ips)} entries.")
        sys.exit(2) # Exit with a custom code to signal a reload is needed
    except IOError as e:
        print(f"Error: Could not write to file {output_path}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update Apache Googlebot allowlist only if changed.")
    parser.add_argument("output", help="Path to the output .conf file")
    
    args = parser.parse_args()
    update_if_changed(args.output)
