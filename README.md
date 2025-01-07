# npr2mp3

Build an album of audio tracks from each given NPR programme

## Description

Each NPR news program has a page for today's airing. These scripts scrape each program's page, identifying the MP3 download links and building a playlist with accompanying titles. Files are then gathered, downcoded to low bitrate mono and id3 tagged as an "Album" with numbered tracks and titles. 

### Advantages
* When packaged as an album, you can see the title of each story and know if you care about it or have heard it before (because reruns)
* You can skip to the next story at will!
* All underwriting credits and ads are cleverly omitted :imp:

Supported Programs:
* All Things Considered
* Morning Edition
* Fresh Air
* Wait Wait Don't Tell Me
* Weakened Edition

## Dependencies

* Linux or MacOS
* lame

## Cron Entries 

It currently runs well from cron. Not sure if daemon/sysctl is warranted. 

These were learned as good times to expect all story files to be available. Sometimes you're going to miss 1 or 2, if it's a big/hot news day.
```
52 6 * * 1-5 $HOME/bin/npr.py me 2>&1
56 6 * * 1-5 $HOME/bin/nprgrab.py me 2>&1
35 16 * * 1-5 $HOME/bin/npr.py fa 2>&1
39 16 * *  1-5 $HOME/bin/nprgrab.py fa 2>&1
52 16 * * * $HOME/bin/npr.py atc 2>&1
56 16 * *  * $HOME/bin/nprgrab.py atc 2>&1
22 8 * * 6 $HOME/bin/npr.py wesat 2>&1
26 8 * *  6 $HOME/bin/nprgrab.py wesat 2>&1
0 23 * * 6 $HOME/bin/npr.py ww 2>&1
2 23 * * 6 $HOME/bin/nprgrab.py ww 2>&1
35 23 2 7 * $HOME/bin/npr.py fa 2>&1
39 23 2 7 * $HOME/bin/nprgrab.py fa 2>&1
```

## To Do

* Clean up the **we[sat|sun]** issue, this was dropped in the python rewrite 
* Rewrite backdating, probably doesn't work well now or at all
* Merge 2 scripts into one. I think it originated with a need for 2 butt no longer has that.
* _Build in cleanup of marker files (and others?) (pending test/QA)_
* _Build in cleanup of older audio files, for self-containment (pending test/QA)_
* Package the whole thing for AWS Lambda or GCP Cloud Functions

## Help

```
Usage: {sys.argv[0]} <program> [<MMDDYYYY>]
    where program can be atc, fa, me, wesat, wesun, we, ww"
    Date defaults to current day
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
