#!/usr/bin/env python3

import json
import os
import re
import sys
import shutil
import subprocess
from datetime import datetime
#from bs4 import BeautifulSoup

# Constants
MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

PROGRAMS = {
    'atc': 'all-things-considered',
    'me': 'morning-edition',
    'wesat': 'weekend-edition-saturday',
    'wesun': 'weekend-edition-sunday',
    'fa': 'fresh-air',
    'ww': 'wait-wait-dont-tell-me'
}
LPATH = "/var/www/html/"

def log_message(message):
    """Log messages with timestamp"""
    timestamp = datetime.now().strftime("%b %d %H:%M:%S")
    log_file = os.path.join(LPATH, "nprgrab")
    
    log_entry = f"[{timestamp}] (nprgrab) {message}\n"
    if 'TERM' in os.environ:
        print(log_entry, end='')
    
    with open(log_file, 'a') as f:
        f.write(log_entry)

def do_mail(message):
    """Send email notification"""
    print(message)  # Replace with proper email sending if needed

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <profile> [<MMDDYYYY>]")
        print(" Date defaults to current day.")
        sys.exit(1)

    prog = sys.argv[1].strip()
    dir_path = "/var/www/html"
    pgid = PROGRAMS.get(prog)
    
    if not pgid:
        print(f"Unknown program: {prog}")
        sys.exit(1)

    # Handle date processing
    if len(sys.argv) == 2:
        # Current date
        today = datetime.now()
        year = today.strftime("%Y")
        month = today.strftime("%m")
        day = today.strftime("%d")
        wdate = today.strftime("%w")
        tod = today.strftime("%Y%m%d")
        urldate = f"{year}-{month}-{day}"
        
        mark = f"/var/tmp/{prog}{month}{day}"
        if os.path.exists(mark):
            log_message(f"Flag file {mark} exists, exiting")
            sys.exit(0)
            
    elif len(sys.argv) == 3:
        # Specific date
        dat = sys.argv[2].strip()
        year = dat[:4]
        month = dat[4:6]
        day = dat[6:8]
        urldate = f"{year}-{month}-{day}"
        fdstr = dat[-4:]
    
    # Construct archive URL and fetch content
    arch = f"http://www.npr.org/programs/{pgid}/archive"
    
    # Fetch archive page
    try:
        cmd = f"wget -qO - {arch} | grep 'showDate={urldate}' | head -1"
        preurl = subprocess.check_output(cmd, shell=True).decode('utf-8').strip()
        
        if not preurl:
            log_message("Error: URL for {urldate} not found in archive page for {pgid}.")
            sys.exit(1)
            
        # Extract URL from response
        url_match = re.search(r'href="([^"]+)"', preurl)
        if not url_match:
            log_message("Error: Could not extract URL from archive page response")
            sys.exit(1)
            
        url = url_match.group(1)
        
    except subprocess.CalledProcessError:
        log_message(f"Error: request failed for {urldate} archive page for {pgid}.")
        #do_mail(f"Error: request failed for {urldate} archive page for {pgid}.")
        sys.exit(2)

    # Handle playlist file operations
    if len(sys.argv) == 2:
        playlist_path = f"{dir_path}/{prog}.m3u"
        if os.path.exists(playlist_path):
            #shutil.copy2(playlist_path, LPATH)
            with open(playlist_path, 'r') as f:
                line_count = sum(1 for _ in f)
            shutil.copy2(playlist_path, f"{playlist_path}.last")
            
        m3u_file = open(playlist_path, 'w')
    else:
        m3u_file = open(f"{dir_path}/{prog}-{fdstr}.m3u", 'w')

    # Fetch and process program page
    output_file = "/var/tmp/nprout"
    log_message(f"requesting url {url} and writing to {output_file}")
    subprocess.run(['wget', '-qO', output_file, url])
    
    playlist = []
    tblob = []
    with open(output_file, 'r') as f:
        content = f.read()
        
        # Extract titles and URLs
        #<div class=\"audio-module-controls-wrap\" data-audio='"
        tblob = re.findall(r"\" data-audio='([^\']+)'", content)
        size = len(tblob)
        if size == 0:
            log_message(f"ERROR: tblob has no size, exiting")
            sys.exit(2)
        for story in tblob:
          data = json.loads(story)
          playlist.append(f"# " + data["title"])
          #playlist.append(data["title"])
          rawurl = data["audioUrl"]
          chunx = rawurl.split("?") 
          playlist.append(chunx[0])

#        # Process and filter content
#        for title in titles:
#            if not title or 'Morning News Brief' in title or f'{day}, {year}' in title:
#                continue
#                
#            # Clean up title
#            title = re.sub(r'[\(\*\)\;\@\?\']', '', title)
#            for word in ['To', 'The', 'Or', 'And', 'With', 'For']:
#                title = title.replace(f' {word} ', f' {word.lower()} ')
#            
#            playlist.append(f"# {title}")
#
#        # Add MP3 URLs
#        for mp3_url in mp3_urls:
#            if 'news_brief' in mp3_url or tod not in mp3_url:
#                continue
#            if re.search(r'[0-9]+m[0-9]+\.mp3', mp3_url):
#                continue
#            playlist.append(mp3_url)
#
    # Write playlist
    plen = len(playlist)
    if plen == 0:
        log_message(f"ERROR: playlist has no size, exiting")
        sys.exit(2)

    for item in playlist:
        m3u_file.write(f"{item}\n")
    m3u_file.close()

    # Handle special cases for morning edition and all things considered
    tx = len([url for url in playlist if url.startswith('http')])
    if prog == 'me' and tx < 10 and not os.environ.get('TERM'):
        log_message(f"Found too few story links for {prog} ({tx}), discarding playlist")
        try:
            os.remove(f"{dir_path}/{prog}.m3u")
        except OSError as e:
            log_message(f"Failed to remove playlist: {e}")

    if prog == 'atc' and wdate in '12345' and tx < 12 and not os.environ.get('TERM'):
        log_message(f"Found too few story links for {prog} ({tx}), discarding playlist")
        try:
            os.remove(f"{dir_path}/{prog}.m3u")
        except OSError as e:
            log_message(f"Failed to remove playlist: {e}")

if __name__ == "__main__":
    main()
