#!/usr/bin/perl
use Net::SMTP;
use File::Copy;
use MIME::Lite;

$usage = "Usage: $0 <fa|we|me|atc|ww> [#]\n where # is number of days ago\n";

if(!@ARGV){
	print $usage;
	exit(2);
}
chomp($prg = $ARGV[0]);
if($prg !~ /fa|we|me|atc|ww/){
	print $usage;
	print "($prg)\n";
	exit(2);
}
$prog = $prg;
#if($prg eq "me"){
#	$prog = "morning";
#}
$npath = "/home/elyons/radio";
$tpath = "/var/tmp";
$plist = "/var/www/html/" . $prg . ".m3u";
%tits = ('fa'=>'Fresh Aire', 'wesat'=>'Weakened Edition Saturday', 'wesun'=>'Weakened Edition Sunday', 'me'=>'Morning Edition', 'atc'=>'All Things Considered', 'ww'=>'Wait Wait Dont Tell Me');
chomp($year = `/bin/date +\%Y`);
chomp($d = `/bin/date +\%m\%d`);
chomp($w = `/bin/date +\%w`);
$dstr = "$year$d";
$mark = "/var/tmp/" . $prg . $d;
if($ARGV[1]){
	chomp($off = $ARGV[1]);
	if($off !~ /^[0-9]+$/){
		print $usage;
		print "($off)\n";
		exit(2);
	}
	$dcmd = "/bin/date -d \"$off days ago\" +\%m\%d";
	$wcmd = "/bin/date -d \"$off days ago\" +\%w";
	$ycmd = "/bin/date -d \"$off days ago\" +\%Y";
	chomp($d = `$dcmd`);
	chomp($w = `$wcmd`);
	chomp($year = `$ycmd`);
	$mark = "/var/tmp/" . $prg . $d;
}
else{
	if((-e "$mark")&&(!$ENV{TERM})){
# need to work on this...
#		@dif = `diff /var/tmp/$prg.m3u /var/www/html/$prg.m3u`;
#		if($? == 0){
			&logg("job already completed for $prg$d");
			exit();
#		}
#		foreach $l (@diff){
#			next unless($l =~ /^</);
#			$l =~ s/^< //;
#			&logg("playlist differs from previous: $l");
#			open(ADDS, ">>$plist");
#			print ADDS $l;
#			close(ADDS);
#		}
	}
	else{
		&logg("flag file $mark not found, proceeding");
	}
	if(-e "$plist"){
		if(-z "$plist"){
			&logg("playlist file $plist has no size, deleting");
			unlink($plist);
			exit();
		}
		$mtime = (stat("$plist"))[9];
#		$age = strftime("%H", localtime($mtime));
#		$hour = strftime("%H", localtime(time));
		$hour = time;
		$diff = $hour - $mtime;
		if($diff > 28800){
			&logg("playlist file $plist is stale, aborting");
			unlink($plist);
			exit(3);
		}
	}
	else{
		&logg("playlist file $plist is absent");
		exit();
	}
}
if($prg eq "we"){
	if($w == 6){
		$prg = "wesat";
	}
	elsif($w == 0){
		$prg = "wesun";
	}
	else{
		print "Error, not a weekend: d = ".$d.", w = ".$w." \n";
		exit(2);
	}
}
chdir($tpath);
$get = "/usr/bin/wget -q -T 30 -O " . $prg . "\.m3u http://lumpy/" . $prg;
if($ARGV[1]){
#	chomp($plist = $ARGV[2]);
#	$get = "/usr/bin/wget -q -T 30 -O " . $prg . "\.m3u http://lumpy/" . $prg . "-" . $d . "\.m3u"; 
	$get .= "-" . $d; 
	if($ENV{TERM}){
		print "$get\n";
	}
}
$get .= "\.m3u";
if(system($get)!=0){
	&logg("wget failed for playlist $prog");
	if($ENV{TERM}){print "URL: $get\n";}
	exit(1);
}
my $got = $prog . "\.m3u";
if(! -e "$got"){
	&logg("playlist $got not found after wget");
	exit(1);
}
$done=0;
foreach $url (`cat $got`){
#	my $song = "Unknown Title";
	chomp($url);
	if($url =~ /^\# (.+)$/){
		$song = $1;
		$song =~ s/\'//g;
		$song =~ s/ Or / or /g;
		$song =~ s/ Of / of /g;
		$song =~ s/ And / and /g;
		$song =~ s/ The / the /g;
		next;
	}
	# http://public.npr.org/anon.npr-mp3/npr/me/2011/01/20110106_me_14.mp3
	elsif($url =~ /^http.+\.mp3/){
		$fname = $1 . "_" . $prg . "_" . $2 . "\.mp3";
		$i++;
		$t = $i;
		if($i < 10){
			$t = "0" . $i;
		}
		$oname = $prg . $d . "t" . $t . "\.mp3";
		if(-e "$npath/$oname"){
			&logg("File $oname already exists, skipping.");
			next;
		}
		else{
			if($ENV{TERM}){
				print "Grabbing " . $prg . $d . " track $t...\n";
			}
#			if(system("/usr/bin/wget -q $url")!=0){
			if(system("/usr/bin/wget -qO $fname $url")!=0){
				&logg("wget failed for $url: $!");
				next;
			}
			unless(-e "$tpath/$fname"){
				if(system("/bin/mv $tpath/$fname* $tpath/$fname")!=0){
					&logg("move failed for $fname: $!");
					next;
				}
			}
			$recode = "/usr/bin/lame -a -m m -b 24 --resample 16 --scale 2 --quiet --add-id3v2 --ta NPR";
			$recode .= " --tl \"".$d." ".$tits{$prg}. "\"";
			if($song =~ /.+/){
				$recode .= " --tt \"".$song."\"";
			}
			else{
				$recode .= " --tt \"".$tits{$prg}." ".$t."\"";
			}
			$recode .= " --ty \"$year\"";
			$recode .= " --tn \"$t\"";
			$recode .= " --tg \"Speech\"";
			$oname =~ s/^wes[atun]+/we/;
			if(-e "$npath/$oname"){
				print "File $oname already retrieved, skipping\n";
				next;
			}
			if(system("$recode $tpath/$fname $npath/$oname 2>&1 >/dev/null")==0){
	#			&logg("Re-encoded and tagged file $fname");
				$done++;
				push(@flies, $oname);
				unlink("$tpath/$fname") or &logg("Debug: unlink returned false on $tpath/$fname: $!");
			}
			else{
				&logg("Warning, lame re-encoding failed on $fname");
			#	&lamer($fname);
			}
		}
#		push(@flies, $fname);
	}
	else{
		&logg("no regex match on $url");
	}
}
if($done < 1){
	&logg("no files available after wgets");
	exit(1);
}
else{
	if(! -e "$mark"){
		system("echo $done > $mark");
	}
	$done .= " file";
	if($done != 1){
		$done .= "s";
	}
	&logg("Re-encoded and tagged $done");
	$repor = "Re-encoded and tagged $done for $prog\n";
	chdir($npath);
}
$prg =~ s/^wes[atun]+/we/;
@brony = `rsync -auv $npath/$prg$d* 192.168.0.43:Music/mp3/ 2>\&1`;
if($?!=0){
	&logg("rsync to brony at wired address failed");
	$repor .= "rsync to brony at wired address failed\n";
	@brony = `rsync -auv $npath/$prg$d* 192.168.0.9:Music/mp3/ 2>\&1`;
	if($?!=0){
		&logg("rsync to brony at wifi address failed, aborting");
		$repor .= "rsync to brony at wifi address failed, aborting\n";
	}
}
if(grep(/mp3/, @brony)){
	@sent = grep(/\.mp3$/, @brony);
	$dunn = scalar(@sent);
	&logg("Copied $dunn files to brony for $prg");
	$repor .= "Copied $dunn files to brony for $prg\n";
	open(SENT, ">/var/tmp/went2brony");
	foreach $b (@brony){
		next if($b !~ /mp3/);
		chomp($b);
		$b =~ s/^([^\s]+)\s+.*$/$1/;
		print SENT "$b\n";
	}
	close(SENT);
}
else{
	&logg("No files were copied to brony for $prg");
	$repor .= "No files were copied to brony for $prg\n";
}
&domail($repor);
print "seem to have reached the end.\n" if($ENV{TERM});
exit();
sub logg( "$" ){
	chomp($tim = `date +\"\%b \%d \%T\"`);
#	$tim = localtime(time);
	$out = "@_";
	$lfile = "/home/elyons/log/nprgrab";
	open(LOG, ">>$lfile") or die "Can't open logfile $lfile: $!\n";
	select LOG unless($ENV{TERM});
	print "[$tim] (nprgrab) $out\n";
	close(LOG);
}
sub domail( "$" ){
	$tim = localtime(time);
	chomp($host = `hostname`);
	$subject = "Files available for $prog";
	$bod= "@_";
	&logg($bod);
	$bod .= "\nMessage generated $tim by $host:$0\n";
	$msg = MIME::Lite->new(
	#	SetSender=>'rserling@pantload.net',
	#	Return-Path =>'rserling@pantload.net',
	#	From    =>'rserling@pantload.net',
		SetSender=>'wolfstools@gmail.com',
		Return-Path =>'wolfstools@gmail.com',
		From    =>'wolfstools@gmail.com',
		To      =>'bitshag@gmail.com',
		Subject =>"$subject",
		Type    =>'text/plain',
		Data =>"$bod"
	);
	$msg->send;
}
