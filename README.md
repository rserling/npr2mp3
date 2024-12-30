# npr2mp3

Build an album of audio tracks from each given NPR programme

## Description

Each NPR news program has a page for today's airing. These scripts scrape each program's page, identifying the MP3 download links and building a playlist with accompanying titles. Files are then gathered, downcoded to low bitrate mono and id3 tagged as an "Album" with numbered tracks and titles. 

Supported Programs:
* Morning Edition
* All Things Considered
* Weakened Edition
* Fresh Air
* Wait Wait Don't Tell Me

### Dependencies

* Linux or MacOS
* lame, ffmpeg

### Cron Entries 

These were learned over time as good times to expect all story files to be available.
```
52 6 * * 1-5 $HOME/bin/npr.py me 2>&1
56 6 * * 1-5 $HOME/bin/nprgrab.py me 2>&1
35 16 * * 1-5 $HOME/bin/npr.py fa 2>&1
39 16 * *  1-5 $HOME/bin/nprgrab.py fa 2>&1
52 16 * * * $HOME/bin/npr.py atc 2>&1
56 16 * *  * $HOME/bin/nprgrab.py atc 2>&1
22 8 * * 6 $HOME/bin/npr.py we 2>&1
26 8 * *  6 $HOME/bin/nprgrab.py we 2>&1
0 23 * * 6 $HOME/bin/npr.py ww 2>&1
2 23 * * 6 $HOME/bin/nprgrab.py ww 2>&1
35 23 2 7 * $HOME/bin/npr.py fa 2>&1
39 23 2 7 * $HOME/bin/nprgrab.py fa 2>&1

# cleanup, delete files > 3 days old
10 10 * * * /usr/bin/find $HOME/Music/radio -mtime +3 -type f -delete 2>&1
```

## To Do

* Too silent on re-run (doing nothing), needs to log
* Merge 2 scripts into one
* Restructure logging 
* Build in cleanup of marker files (and others?)
* Build in cleanup of older audio files, for self-containment

## Help

Any advise for common problems or issues.
```
command to run if program contains helper info
```

## Authors

Contributors names and contact info

ex. Dominique Pizzie  
ex. [@DomPizzie](https://twitter.com/dompizzie)

## Version History

* 1.x
  * Initial implementation in PERL
* 2.0.0
  * Rewritten in Python 

## License

This project is licensed under the [ErikNerd] License - see the LICENSE.md file for details, or if it doesn't exist, please disregard.

## Acknowledgments

Inspiration, code snippets, etc.
* [awesome-readme](https://github.com/matiassingers/awesome-readme)
* [PurpleBooth](https://gist.github.com/PurpleBooth/109311bb0361f32d87a2)
* [dbader](https://github.com/dbader/readme-template)
* [zenorocha](https://gist.github.com/zenorocha/4526327)
* [fvcproductions](https://gist.github.com/fvcproductions/1bfc2d4aecb01a834b46)
