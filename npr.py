#!/usr/bin/env python3

import json
import os
import re
import sys
import shutil
import subprocess
import time
from datetime import datetime, timedelta
from pathlib import Path
import smtplib
from email.mime.text import MIMEText

# Constants
PROGRAMS = {
    'atc': 'all-things-considered',
    'fa': 'fresh-air',
    'me': 'morning-edition',
    'wesat': 'weekend-edition-saturday',
    'wesun': 'weekend-edition-sunday',
    'ww': 'wait-wait-dont-tell-me'
}

TITLES = {
    'atc': 'All Things Considered',
    'fa': 'Fresh Aire',
    'me': 'Morning Edition',
    'wesat': 'Weakened Edition Saturday',
    'wesun': 'Weakened Edition Sunday',
    'ww': 'Wait Wait Dont Tell Me'
}

BASE = os.getenv("HOME")
LPATH = os.path.join(BASE, "Music")
NPATH = os.path.join(LPATH, "radio")
TPATH = "/var/tmp"

def log_message(message):
    timestamp = datetime.now().strftime("%b %d %H:%M:%S")
    log_file = os.path.join(LPATH, "nprgrab.log")
    log_entry = f"[{timestamp}] (npr) {message}\n"
    if 'TERM' in os.environ:
        print(log_entry, end='')
    with open(log_file, 'a') as f:
        f.write(log_entry)

def send_email(subject, body):
    hostname = subprocess.getoutput('hostname')
    timestamp = datetime.now().strftime("%c")
    body += f"\nMessage generated {timestamp} by {hostname}:{sys.argv[0]}\n"
    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = os.getenv('SMTP_FROM', 'wolfstools@gmail.com')
    msg['To'] = 'bitshag@gmail.com'
    try:
        with smtplib.SMTP('localhost') as s:
            s.send_message(msg)
        return True
    except Exception as e:
        log_message(f"ERROR: Email send failed: {str(e)}")
        return False

def scrape(prog, prg, urldate, year, month, day, wdate, dir_path, fdstr=None):
    pgid = PROGRAMS[prg]
    arch = f"http://www.npr.org/programs/{pgid}/archive"

    try:
        cmd = f"wget -qO - {arch} | grep 'showDate={urldate}' | head -1"
        preurl = subprocess.check_output(cmd, shell=True).decode('utf-8').strip()
        if not preurl:
            log_message(f"ERROR: URL for {urldate} not found in archive page for {pgid}.")
            sys.exit(1)
        url_match = re.search(r'href="([^"]+)"', preurl)
        if not url_match:
            log_message(f"ERROR: Could not extract URL from archive page response")
            sys.exit(1)
        url = url_match.group(1)
    except subprocess.CalledProcessError:
        log_message(f"ERROR: request failed for {urldate} archive page for {pgid}.")
        sys.exit(2)

    playlist_path = f"{dir_path}/{prg}.m3u"
    if fdstr is None:
        if os.path.exists(playlist_path):
            with open(playlist_path, 'r') as f:
                sum(1 for _ in f)
            shutil.copy2(playlist_path, f"{playlist_path}.last")
        m3u_file = open(playlist_path, 'w')
    else:
        m3u_file = open(f"{dir_path}/{prg}-{fdstr}.m3u", 'w')

    output_file = "/var/tmp/nprout"
    log_message(f"requesting url {url} and writing to {output_file}")
    subprocess.run(['wget', '-qO', output_file, url])

    playlist = []
    with open(output_file, 'r') as f:
        content = f.read()
        tblob = re.findall(r"\" data-audio='([^\']+)'", content)
        size = len(tblob)
        log_message(f"DEBUG: Found {size} audioUrl matches")
        if size == 0:
            log_message(f"ERROR: tblob has no size, exiting")
            sys.exit(2)
        title = ""
        for story in tblob:
            try:
                data = json.loads(story)
            except (json.JSONDecodeError, Exception) as e:
                log_message(f"ERROR: JSON parse failed: {e}")
                continue
            if "title" not in data or "audioUrl" not in data:
                log_message(f"ERROR: Missing required keys in JSON")
                continue
            tit = data["title"]
            if tit == title:
                continue
            title = tit
            if prg == 'me':
                title_lower = title.lower()
                if 'news brief' in title_lower or 'newsbrief' in title_lower:
                    log_message("INFO: Skipping Morning News Brief")
                    continue
            playlist.append(f"# {title}")
            rawurl = data["audioUrl"]
            playlist.append(rawurl.split("?")[0])

    if not playlist:
        log_message(f"ERROR: playlist has no size, exiting")
        sys.exit(2)

    for item in playlist:
        m3u_file.write(f"{item}\n")
    m3u_file.close()

    tx = len([u for u in playlist if u.startswith('http')])
    if prg == 'me' and tx < 10 and not os.environ.get('TERM'):
        log_message(f"Found too few story links for {prg} ({tx}), discarding playlist")
        try:
            os.remove(playlist_path)
        except OSError as e:
            log_message(f"ERROR: Failed to remove playlist: {e}")

    if prg == 'atc' and wdate in '12345' and tx < 12 and not os.environ.get('TERM'):
        log_message(f"ERROR: Found too few story links for {prg} ({tx}), discarding playlist")
        try:
            os.remove(playlist_path)
        except OSError as e:
            log_message(f"ERROR: Failed to remove playlist: {e}")

def grab(prg, date_str, year, playlist_path):
    mark_file = os.path.join(TPATH, f"{prg}{date_str}")

    if os.path.exists(mark_file):
        log_message(f"WARN: job already completed for {prg}{date_str}")
        sys.exit(0)

    if not os.path.exists(playlist_path):
        log_message(f"ERROR: playlist file {playlist_path} is absent")
        sys.exit(0)

    if os.path.getsize(playlist_path) == 0:
        log_message(f"ERROR: playlist file {playlist_path} has no size, deleting")
        os.unlink(playlist_path)
        sys.exit(0)

    mtime = os.path.getmtime(playlist_path)
    if (time.time() - mtime) > 28800:
        log_message(f"WARN: playlist file {playlist_path} is stale, aborting")
        os.unlink(playlist_path)
        sys.exit(3)

    os.chdir(TPATH)
    done = 0

    with open(playlist_path) as f:
        story = "Unknown Title"
        track_num = 0
        for line in f:
            line = line.strip()
            if line.startswith('# '):
                new_story = line[2:]
                if new_story == story:
                    continue
                story = new_story.replace("'", "")
                for word in ['Or', 'Of', 'And', 'The', 'For', 'A', 'An']:
                    story = story.replace(f" {word} ", f" {word.lower()} ")
                continue
            if line.endswith('.mp3') and line.startswith('http'):
                track_num += 1
                track_str = f"{track_num:02d}"
                output_name = f"{prg}{date_str}t{track_str}.mp3"
                if os.path.exists(os.path.join(NPATH, output_name)):
                    log_message(f"WARN: File {output_name} already exists, skipping.")
                    done += 1
                    continue
                if 'TERM' in os.environ:
                    print(f"Grabbing {prg}{date_str} track {track_str}...")
                try:
                    subprocess.run(['wget', '-qO', output_name, line], check=True)
                    lame_cmd = [
                        'lame', '-a', '-m', 'm', '-b', '24', '--resample', '16',
                        '--scale', '2', '--quiet', '--add-id3v2',
                        '--ta', 'NPR',
                        '--tl', f"{date_str} {TITLES[prg]}",
                        '--ty', year,
                        '--tn', track_str,
                        '--tg', 'Speech'
                    ]
                    if story != "Unknown Title":
                        lame_cmd.extend(['--tt', story])
                    lame_cmd.extend([output_name, os.path.join(NPATH, output_name)])
                    subprocess.run(lame_cmd, check=True, capture_output=True)
                    done += 1
                    os.unlink(output_name)
                except subprocess.CalledProcessError as e:
                    log_message(f"ERROR: Error processing {output_name}: {str(e)}")

    if done < 1:
        log_message("ERROR: no files available after downloads")
        sys.exit(1)

    with open(mark_file, 'w') as f:
        f.write(str(done))
    files_text = "file" if done == 1 else "files"
    log_message(f"INFO: Re-encoded and tagged {done} {files_text} for {prg}")

def main():
    usage = (f"Usage: {sys.argv[0]} <program> [<days_ago>]\n"
             f" where program can be atc, fa, me, wesat, wesun, ww\n"
             f" optional second arg is number of days ago\n")

    if len(sys.argv) < 2:
        print(usage)
        sys.exit(2)

    prg = sys.argv[1].strip()
    if prg not in PROGRAMS:
        print(usage)
        print(f"({prg})")
        sys.exit(2)

    fdstr = None
    if len(sys.argv) > 2:
        try:
            days_ago = int(sys.argv[2])
            target_date = datetime.now() - timedelta(days=days_ago)
            fdstr = target_date.strftime("%m%d")
        except ValueError:
            print(usage)
            sys.exit(2)
    else:
        target_date = datetime.now()

    year  = target_date.strftime("%Y")
    month = target_date.strftime("%m")
    day   = target_date.strftime("%d")
    wdate = target_date.strftime("%w")
    date_str = f"{month}{day}"
    urldate = f"{year}-{month}-{day}"

    if fdstr is None:
        mark = os.path.join(TPATH, f"{prg}{date_str}")
        if os.path.exists(mark):
            log_message(f"WARN: Flag file {mark} exists, exiting")
            sys.exit(0)

    playlist_path = os.path.join(LPATH, f"{prg}.m3u")

    scrape(prg, prg, urldate, year, month, day, wdate, LPATH, fdstr)
    grab(prg, date_str, year, playlist_path)

if __name__ == "__main__":
    main()
