#!/usr/bin/perl

use MIME::Lite;
use File::Copy;
#use Cal::Date qw(today ISO_day MJD);
@months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

#%programs = (WC=>39, atc=>2, ME=>3, TOTN=>5, WESAT=>7, WESUN=>10, FA=>13, DAY=>17, WW=>35);
#%programs = (WC=>39, atc=>'all_things_considered', ME=>'morning_edition', TOTN=>5, WESAT=>7, WESUN=>10, FA=>13, DAY=>17, WW=>35);
%programs = (wc=>39, atc=>'all-things-considered', me=>'morning-edition', totn=>5, wesat=>'weekend-edition-saturday', wesun=>'weekend-edition-sunday', fa=>'fresh-air', ww=>'wait-wait-dont-tell-me');

$prog = $ARGV[0];
chomp($prog);
$dir = "/var/www/html";

$pgid = $programs{$prog};
if(@ARGV == 1){
# prepare datestring for current day
	chomp($wdate = `date +%w`);
	chomp($tod = `date +%Y%m%d`);
# 20050429
	$year = substr($tod, 0,4);
	$day = substr($tod, -2,2);
	$month = substr($tod, -4,2);
	$mo = $months[(substr($tod, -4,2))-1];
	$dstr = "$tod";
	$urldate = "$year-$month-$day";
	$mark = "/var/tmp/" . $prog . $month . $day;
	if(-e "$mark"){
		&logg("Flag file $mark exists, exiting");
		exit();
	}	
	$arch="http://www.npr.org/programs/$pgid/archive";
## need error checking on this wget...
	chomp($preurl = `wget -qO - $arch |grep 'showDate=$urldate' |head -1`);
	if($? != 0){
		&domail("Error: request failed for $urldate archive page for $pgid.");
		exit(2);
	}	
#	chomp($preurl = `wget -O - $arch |grep 'showDate=$urldate\">'`);
	if($preurl =~ /href=\"([^\"]+)\"/){
		$url = $1;
	}
	else{
		print "Error: URL for $urldate not found in archive page for $pgid.\n";
		print "Pre-URL contains: $preurl\n";
		exit(1);
	}
	if(-e "$dir/$prog.m3u"){
		system("cat $dir/$prog.m3u >>$dir/$prog.log");
		chomp($wc = `wc -l $dir/$prog.m3u`);
		copy("$dir/$prog.m3u", "/var/tmp/");
	}
	open(M3U, ">$dir/$prog.m3u") or die "Can't open file:$!\n";
	copy("$dir/$prog.m3u", "$dir/$prog.m3u.last");
#	open(wM3U, ">$dir/wm-$prog.m3u") or die "Can't open file:$!\n";
#	$flag = "/var/tmp/" . $prog;
	$flag = "/var/tmp/" . $prog . $month . $day;
}
# datestring can be from any date in the past
elsif(@ARGV == 2) {
	chomp($dat = $ARGV[1]);
#	$pgid = $programs{$pcode};
	print "pgid = $pgid\n";
	$day = substr($dat, -2,2);
	$month = substr($dat, -4,2);
	$mo = $months[$month-1];
	$year = substr($dat, 0,4);
	$fdstr = substr($dat, -4,4); 
	$dstr = "$dat";
	$urldate = "$year-$month-$day";
	#$url = "http://www.npr.org/programs/$prog";
	$arch="http://www.npr.org/programs/$pgid/archive";
#	<a class="full-show" href="http://www.npr.org/programs/morning-edition/2013/12/20/255698889/morning-edition-for-december-20-2013?showDate=2013-12-20
#	<a href="http://www.npr.org/programs/morning-edition/2014/03/21/292225680/morning-edition-for-march-21-2014?showDate=2014-03-21"  data-metrics='{"action":"Click Archive View Full Show","category":"News Magazine Archive","label":"http:\/\/www.npr.org\/programs\/morning-edition\/2014\/03\/21\/292225680\/morning-edition-for-march-21-2014"}' >
	chomp($preurl = `wget -qO - $arch |grep 'showDate=$urldate' |head -1`);
#	chomp($preurl = `wget -O - $arch |grep 'showDate=$urldate\">'`);
	if($preurl =~ /href=\"([^\"]+)\"/){
		$url = $1;
	}
	else{
		print "Error: URL for $urldate not found in archive page for $pgid.\n";
		print "Debug: $preurl\n";
		exit(1);
	}
	#$url = "http://www.npr.org/templates/rundowns/rundown.php?prgId=$pgid\&prgDate=$urldate\&view=storyview";
	$flag = "/var/tmp/" . $prog . $month . $day;
### if grabbing archive, don't overwrite today's playlist, make new
	open(M3U, ">/var/www/html/$prog-$fdstr.m3u") or die "Can't open file:$!\n";
}
else {
	print "Usage: $0 <profile> [<MMDDYYYY>].\n";
	print " Date defaults to current day.\n";
	exit(1);
}

if($pcode eq "ww"){
	$pcode = "waitwait";
}

$blat = "/var/www/html/nprout";

if($ENV{TERM}){
	print "Requesting $url...\n";
}
system("wget -qO $blat '$url'");
#system("perl -p -i -e \'s/></>\n</g\' $blat");
open(OUTPUT, $blat); # should test for age
#$cnt = 1;
my @plist;
foreach $line (<OUTPUT>){
#	<input type="hidden" id="title252006903" value="Obama Meets With Tech Leaders, Taps Microsoft Exec To Fix HealthCare.gov"></input>
#<h3 class="rundown-segment__title"><a href="http://www.npr.org/2016/12/24/506849921/how-kitchen-sounds-influence-food-flavor"  data-metrics='{"action":"Click Rundown Story 5","category":"Rundown Click","label":"http:\/\/www.npr.org\/2016\/12\/24\/506849921\/how-kitchen-sounds-influence-food-flavor"}' >How Kitchen Sounds Influence Food Flavor</a></h3>
#
	chomp;
#	if($line =~ /id=\"title([0-9]+)\" value=\"([^\"]+)\"/){
	if($line =~ /' >([^<]+)<\/a><\/h3>/){
		$tit = "unknown title";
#		chomp($sid = $1);
#		chomp($tit = $2);
		chomp($tit = $1);
		next if($tit =~ /.+$day, $year$/);
#		$tit = $2 if($2 =~ /\w/);
		$tit =~ s/[\(\*\)]//g;
		$tit =~ s/[\(\;\)]//g;
		$tit =~ s/[\@\?\']//g;
		$tit =~ s/ To / to /g;
		$tit =~ s/ The / the /g;
		$tit =~ s/ Or / or /g;
		$tit =~ s/ And / and /g;
		$tit =~ s/ With / with /g;
		$tit =~ s/ For / for /g;
		print "Extracted title: \'$tit\'\n" if($ENV{TERM});
		if(@plist > 1){
			for($i=0; $i<=$#plist; $i++){
				if($plist[$i] =~ /$tit/){
					splice(@plist, $i, 2);
				} 
			}
		}
		push(@plist, "\# $tit");
		$pcode = lc($pcode);
#		http://pd.npr.org/anon.npr-mp3/npr/me/2013/12/20131218_me_24.mp3
#		$mp3url = "http://pd.npr.org/anon.npr-mp3/npr/$pcode/$year/$month/$dstr" . "_" . $pcode . "_";
#  		push(@plist, $mp3url);
#		push(@plist, "http://www.npr.org/dmg/dmg.php\?prgCode=$pcode\&showDate=$dstr\&segNum=");
		$tt++;
#		$cnt++;
	}
#	<li class="download"><a href="http://pd.npr.org/anon.npr-mp3/npr/me/2013/12/20131218_me_opponents_to_challenge_calif_school_act.mp3?dl=1"  data-metrics=
#	 <li><a class="audio-tool audio-tool-download" href="http://pd.npr.org/anon.npr-mp3/npr/atc/2016/03/20160329_atc_remembering_patty_duke_hollywoods_miracle_worker.mp3?orgId=1&amp;topicId=1062&amp;d=251&amp;p=2&amp;story=472309592&amp;t=progseg&amp;e=472228928&amp;seg=19&amp;siteplayer=true&amp;dl=1" 
#<a href="http://www.npr.org/2016/04/12/473992245/criminal-justice-dominates-crowded-baltimore-mayoral-race"  data-metrics='{"action":"Click Rundown Story 1","category":"Rundown Click","label":"http:\/\/www.npr.org\/2016\/04\/12\/473992245\/criminal-justice-dominates-crowded-baltimore-mayoral-race"}' >Criminal Justice Dominates Crowded Baltimore Mayoral Race</a></h1>
# http://pd.npr.org/anon.npr-mp3/npr/atc/2016/04/20160412_atc_criminal_justice_dominates_crowded_baltimore_mayoral_race.mp3?orgId=1&topicId=1014&d=235&p=2&story=473992245&t=progseg&e=473914722&seg=1&siteplayer=true&dl=1

#audio-tool-download"><a href
#
	elsif($line =~ /download\"><a href=\"([^\"]+\.mp3).+/){
		$mp3url = $1;
		next if($mp3url !~ /$dstr/);
#		$mp3url =~ s/\?dl=1$//;
		push(@plist, $mp3url);
		print "Extracted URL: \'$mp3url\'\n" if($ENV{TERM});
		$tx++;
	}
}
close(OUTPUT);
# if no matches, audio links are not ready yet
if(@plist < 1) {
	print "The regex match is failing for $prog.\n" if($ENV{TERM});
#	&domail("The regex match is failing for $prog.");
	exit(1);
}

if(($prog eq "me")&&($tx < 10)&&(!$ENV{TERM})){
	&logg("Found too few story links for $prog ($tx), discarding playlist");
#	unlink("$dir/$prog.m3u") or &logg("unlink failed on $dir/$prog.m3u");
#	unlink($flag) or &logg("unlink failed on $flag");
	$playlist = $dir . "/" . $prog . ".m3u";
	$rmp = "/bin/rm " . $playlist;
	if(system($rmp)!=0){
		&logg("rm failed on $playlist");
	}
	else{
		&logg("removed file $playlist");
		if(-e "$playlist"){
			&logg("but it's still there");
		}
	}
#	$rmf = "/bin/rm " . $flag;
#	if(system($rmf)!=0){
#		$r = $?;
#		&logg("rm failed on $flag ($r)");
#	}
#	if(-e "$flag"){
#		unlink($flag);
#	}
	exit();
}
if(($wdate =~ /[1-5]/)&&($prog eq "atc")&&($tx < 12)&&(!$ENV{TERM})){
	&logg("Found too few story links for $prog ($tx), discarding playlist");
#	unlink("$dir/$prog.m3u") or &logg("unlink failed on $dir/$prog.m3u");
#	unlink($flag) or &logg("unlink failed on $flag");
	$playlist = $dir . "/" . $prog . ".m3u";
	$rmp = "/bin/rm " . $playlist;
	if(system($rmp)!=0){
		&logg("rm failed on $playlist");
	}
	else{
		&logg("removed file $playlist");
		if(-e "$playlist"){
			&logg("but it's still there");
		}
	}
#	if(-e "$flag"){
#		unlink($flag);
#	}
	exit();
}
if(($prog =~ /^we/)&&($tx < 14)){
#	&domail("Found too few story links for $prog ($tx), discarding playlist");
	&logg("Found too few story links for $prog ($tx), discarding playlist");
	$playlist = $dir . "/" . $prog . ".m3u";
	$rmp = "/bin/rm " . $playlist;
	if(system($rmp)!=0){
		&logg("rm failed on $playlist ($?)");
	}
	else{
		&logg("removed file $playlist");
		if(-e "$playlist"){
			&logg("but it's still there");
		}
	}
#	$rmf = "/bin/rm " . $flag;
#	if(system($rmf)!=0){
#		$r = $?;
#		&logg("unlink failed on $flag ($r)");
#	}
#	if(-e "$flag"){
#		unlink($flag);
#	}
	exit();
}
# do the actual work of building the file
$cnt=0;
foreach $line (@plist){
	if($line =~ /^http/){
		$cnt++;
		$tx = $cnt;
		if(($pcode eq "me")&&($cnt == (@plist/2 - 1))){
			$cnt = 50;
		}
		$num = $cnt;
		if($cnt < 10){
			$num = "0" . $cnt;
		}
#		$line .= "$num\.mp3";
#		$line .= "$num\.mp3?dl=1";
	}
	print M3U "$line\n";
#	print "$line\n";
#	$line =~ s/RM/WM/;
#	print wM3U "$line\n";
}
if($ENV{TERM}){
	print "Found $cnt story links for $prog\n";
}
close(M3U);
## this seems to incorrectly unlink $flag...
#if($wc){
#	chomp($nwc = `wc -l $dir/$prog.m3u`);
#	if($nwc > $wc){
#		unlink($flag) or warn "unlink failed on $flag: $!\n";
#	}
#}
if($ENV{TERM}){
	print "Finished reporting, $cnt links in $prog.m3u.\n";
	exit();
}
#&domail();

sub domail(){
	$tim = localtime(time);
	if(@_){
		$subject = "Error: too few links for $prog";
		$msg = "@_";
#		$subject = "Error: no match for $prog";
#		$msg = "The regex match is failing for $prog\n";
		&logg($msg);
	}
	else{
		$subject = "Playlist prepared for $prog";
#		$msg = "\nhttp://www.pyoing.net/$prog.m3u\n";
		$msg .= "Tracks: $tx\n\n";
	}
	$msg .= "Message generated $tim by $0\n";
	$msg = MIME::Lite->new(
		SetSender=>'rserling@comcast.net',
		Return-Path =>'rserling@comcast.net',
		From    =>'rserling@comcast.net',
#		To      =>'elyons@pyoing.net',
		To      =>'bitshag@gmail.com',
		#Cc      =>'bergie@bergie.net',
		Subject =>"$subject",
		Type    =>'text/plain',
		Data =>"$msg"
	);
	$msg->send;
#	if($msg->send){
#		exit();
#		print "send from $sender successful.\n";
#	}
#	else {
#		exit(1);
#		print "send failed.\n";
#	}
}
sub logg($){
	$msg = "@_";
	open(LOG, ">>/var/log/nprgrab");
	select LOG unless($ENV{TERM});
	chomp($d = `date +\"\%b \%d \%T\"`);
	print "[$d] (npr) $msg\n";
	close(LOG);
}
