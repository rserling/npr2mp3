#!/usr/bin/env python3
import os
import time
import sys
import subprocess
from datetime import datetime, timedelta
import smtplib
from email.mime.text import MIMEText
import shutil

# Constants
TITLES = {
    'atc': 'All Things Considered',
    'fa': 'Fresh Aire',
    'me': 'Morning Edition',
    'we': 'Weakened Edition',
    'wesat': 'Weakened Edition Saturday', 
    'wesun': 'Weakened Edition Sunday',
    'ww': 'Wait Wait Dont Tell Me'
}

BASE = os.getenv("HOME")
LPATH = os.path.join(BASE, "Music")
NPATH = os.path.join(LPATH, "radio")
TPATH = "/var/tmp"

def log_message(message):
    """Log messages with timestamp"""
    timestamp = datetime.now().strftime("%b %d %H:%M:%S")
    log_file = os.path.join(LPATH, "nprgrab.log")

    log_entry = f"[{timestamp}] (nprgrab) {message}\n"
    if 'TERM' in os.environ:
        print(log_entry, end='')

    with open(log_file, 'a') as f:
        f.write(log_entry)

def send_email(subject, body):
    """Send email notification"""
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

def main():
    usage = f"Usage: {sys.argv[0]} <atc|fa|me|we|wesat|wesun|ww> [#]\n where # is number of days ago\n"
    
    if len(sys.argv) < 2:
        print(usage)
        sys.exit(2)
        
    prg = sys.argv[1]
    if prg not in ['fa', 'we', 'wesat', 'wesun', 'me', 'atc', 'ww']:
        print(usage)
        print(f"({prg})")
        sys.exit(2)
        
    prog = prg
    
    # Get current date or date offset
    if len(sys.argv) > 2:
        try:
            days_ago = int(sys.argv[2])
            target_date = datetime.now() - timedelta(days=days_ago)
        except ValueError:
            print(usage)
            print(f"({sys.argv[2]})")
            sys.exit(2)
    else:
        target_date = datetime.now()
        
    year = target_date.strftime("%Y")
    date_str = target_date.strftime("%m%d")
    weekday = target_date.strftime("%w")
    
    # Handle weakened edition special case
    if prg == "we":
        if weekday == "6":
            prg = "wesat"
        elif weekday == "0":
            prg = "wesun"
        else:
            print(f"Error, not a weekend: d = {date_str}, w = {weekday}")
            sys.exit(2)
            
    mark_file = os.path.join(TPATH, f"{prg}{date_str}")
    playlist = f"/var/www/html/{prog}.m3u"
    
    # Check if already processed
    if os.path.exists(mark_file):
        log_message(f"WARN: job already completed for {prg}{date_str}")
        sys.exit(0)
        
    # Process playlist
    if not os.path.exists(playlist):
        log_message(f"ERROR: playlist file {playlist} is absent")
        sys.exit(0)
        
    if os.path.getsize(playlist) == 0:
        log_message(f"ERROR: playlist file {playlist} has no size, deleting")
        os.unlink(playlist)
        sys.exit(0)
        
    # Check playlist staleness, frogot use case
    mtime = os.path.getmtime(playlist)
    if (time.time() - mtime) > 28800:  # 8 hours
        log_message(f"WARN: playlist file {playlist} is stale, aborting")
        os.unlink(playlist)
        sys.exit(3)
        
    # Process MP3 files
    os.chdir(TPATH)
    done = 0
    files_processed = []
    
    with open(playlist) as f:
        story = "Unknown Title"
        track_num = 0
        
        for line in f:
            line = line.strip()
            
            # Handle title lines
            if line.startswith('# '):
                new_story = line[2:]
                if new_story == story:
                    continue
                    
                story = new_story
                story = story.replace("'", "")
                for word in ['Or', 'Of', 'And', 'The', 'For', 'A', 'An']:
                    story = story.replace(f" {word} ", f" {word.lower()} ")
                continue
                
            # Handle MP3 URLs
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
                    
                # Download and process file
                try:
                    subprocess.run(['wget', '-qO', output_name, line], check=True)
                    
                    # Build LAME command
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
                    files_processed.append(output_name)
                    os.unlink(output_name)
                    
                except subprocess.CalledProcessError as e:
                    log_message(f"ERROR: Error processing {output_name}: {str(e)}")
                    continue
                    
    if done < 1:
        log_message("ERROR: no files available after downloads")
        sys.exit(1)
    else:
        if not os.path.exists(mark_file):
            with open(mark_file, 'w') as f:
                f.write(str(done))
                
        files_text = "file" if done == 1 else "files"
        log_message(f"INFO: Re-encoded and tagged {done} {files_text} for {prog}")
        
        os.chdir(NPATH)
        log_message("INFO: seem to have reached the end")

if __name__ == "__main__":
    main()
