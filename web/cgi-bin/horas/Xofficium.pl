#!/usr/bin/perl
use utf8;

# Name : Laszlo Kiss
# Date : 01-20-08
# Divine Office
# Modified by Fr. John Lawrence M. Polis 10-15-10

package horas;
#1;
                        
#use warnings;
#use strict "refs";
#use strict "subs";
#use warnings FATAL=>qw(all);

use POSIX;
use FindBin qw($Bin);
use CGI;
use CGI::Cookie;;
use CGI::Carp qw(fatalsToBrowser);
use File::Basename;
use Time::Local;
#use DateTime;
use locale;

use Digest::SHA qw(hmac_sha256_hex);


use lib "$Bin/..";
use DivinumOfficium::Main qw(vernaculars);

$error = '';	 
$debug = '';
our $Tk = 0;
our $Hk = 0;
our $Ck = 0;
our $officium = 'Xofficium.pl';
our $version = 'Rubrics 1960';
@versions = ('Trident 1570', 'Trident 1910', 'Divino Afflatu', 'Reduced 1955', 'Rubrics 1960', '1960 Newcalendar');

#***common variables arrays and hashes
#filled  getweek()
our @dayname; #0=Advn|Natn|Epin|Quadpn|Quadn|Pascn|Pentn 1=winner title|2=other title

#filled by getrank()
our $winner; #the folder/filename for the winner of precedence
our $commemoratio; #the folder/filename for the commemorated
our $scriptura; #the folder/filename for the scripture reading (if winner is sancti)
our $commune; #the folder/filename for the used commune
our $communetype; #ex|vide
our $rank; #the rank of the winner
our $laudes; #1 or 2
our $vespera; #1 | 3 index for ant, versum, oratio
our $cvespera; #for commemoratio
our $commemorated; #name of the commemorated for vigils
our $comrank = 0; #rank of the commemorated office

#filled by precedence()
our %winner; #the hash of the winner 
our %commemoratio; #the hash of the commemorated
our %scriptura; #the hash for the scriptura
our %commune; # the hash of the commune
our (%winner2, %commemoratio2, %commune2); #same for 2nd column
our $rule; # $winner{Rank}
our $communerule; # $commune{Rank}
our $duplex; #1=simplex-feria, 2=semiduplex-feria privilegiata, 3=duplex 
             # 4= duplex majus, 5 = duplex II classis 6=duplex I classes 7=above  0=none

#*** collect standard items
require "$Bin/do_io.pl";
require "$Bin/horascommon.pl";
require "$Bin/dialogcommon.pl";
require "$Bin/Xwebdia.pl";
require "$Bin/setup.pl";
require "$Bin/Xhoras.pl";
require "$Bin/specials.pl";
require "$Bin/specmatins.pl";
if (-e "$Bin/monastic.pl") {require "$Bin/monastic.pl";}
require "$Bin/../../../../../aux_html/bmbe/clavis.pl";

binmode(STDOUT,':encoding(utf-8)');

$q = new CGI;

#get parameters
getini('horas'); #files, colors

$setupsave = strictparam('setup');
$setupsave =~ s/\~24/\"/g;

our ($lang1, $lang2, $expand, $column, $accented);
our %translate; #translation of the skeleton label for 2nd language 

#internal script
%dialog = %{setupstring($datafolder, '', 'horas.dialog')};
if (!$setupsave) {%setup = %{setupstring($datafolder, '', 'horas.setup')};}
else {%setup = split(';;;', $setupsave);}

our $command = strictparam('command'); 
if ($command =~ /prayVesperae/i) {
	# switch to misspelled form for internal use
	$command = prayVespera;
}
our $hora = $command; #Matutinum, Laudes, Prima, Tertia, Sexta, Nona, Vespera, Completorium
our $date1 = strictparam('date1') || strictparam('date'); 
if (!$date1) {$date1 = gettoday();}
if ($command =~ /next/i) {$date1 = prevnext($date1, 1); $command = '';}
if ($command =~ /prev/i) {$date1 = prevnext($date1, -1); $command = '';} 

our $browsertime = strictparam('browsertime');
our $buildscript = ''; #build script
our $searchvalue = strictparam('searchvalue');
if (!$searchvalue) {$searchvalue = '0';}

our $caller = strictparam('caller');
our $dirge = 0; #1=call from 1st vespers, 2=call from Lauds
our $dirgeline = ''; #dates for dirge from Trxxxxyyyy
our $sanctiname = 'Sancti';
our $temporaname = 'Tempora';
our $communename = 'Commune';
    
#*** handle different actions
#after setup
if ($command =~ /change(.*)/i ) { 
 $command = $1;
 getsetupvalue($command);   
 if ($command =~ /parameters/) {setcookies('horasp', 'parameters');}
}    

$setup{'parameters'} = clean_setupsave($setup{'parameters'});

# read settings loaded above from a combination of files
eval($setup{'parameters'}); #$priest, $lang1, colors, sizes
eval($setup{'general'});  #$expand, $version, $lang2       

# Use symbolic names in place of font specifications.
# Ignore the sizes and colors specified in $setup{'parameters'}.
$blackfont='blackfont';
$smallblack='smallblack';
$redfont='redfont';
$initiale='initiale';
$largefont='largefont';
$smallfont='smallfont';
$titlefont='titlefont';

#prepare testmode
our $testmode = strictparam('testmode'); 
if (!$testmode) {$testmode = strictparam('testmode1');} 
if (!$testmode) {$testmode = 'regular';}
our $votive = strictparam('votive');
$expandnum = strictparam('expandnum');    

$p = strictparam('priest');
if ($p) {
  $priest = 1;
  setsetupvalue('parameters', 0, $priest);
}

$p = strictparam('lang1');
if ($p) {
  $lang1 = $p;
  setsetupvalue('parameters', 2, $lang1);
}

$p = strictparam('psalmvar');
if ($p) {
  $psalmvar = $p;
  setsetupvalue('parameters', 3, $psalmvar);
}

$p = strictparam('screenheight');
if ($p) {
  $screenheight = $p;
  setsetupvalue('parameters', 12, $screenheight);
}

$p = strictparam('textwidth');
if ($p) {
  $textwidth = $p;
  setsetupvalue('parameters', 13, $textwidth);
}
$expand = 'all';

$flag = 0;
$p = strictparam('lang2');
if ($p) {$lang2 = $p; $flag = 1;}
$p = strictparam('version');
if ($p) {$version = $p; $flag = 1;}    
$p = strictparam('accented');
if ($p) {$accented = $p; $flag = 1;}   
if ($flag) {
  setsetup('general', $expand, $version, $lang2, $accented);
}
if (!$version) {$version = 'Rubrics 1960';}
if (!$lang2) {$lang2 = 'Latin';}
$only = ($lang1 =~ $lang2) ? 1 : 0;

setmdir($version);

# save parameters
$setupsave = printhash(\%setup, 1);   
$setupsave =~ s/\r*\n*//g;
$setupsave =~ s/\"/\~24/g;	  

# check authentication code
checkauth();

precedence($date1); #fills our hashes et variables  

# check to see if an office on the user's personal calendar should be celebrated
# The office is specified by $mycal, e.g. "Commune/C3.txt 3" = Commune%2FC3.txt%203
#checkMyCal();

our $psalmnum1 = 0;
our $psalmnum2 = 0;                           

# prepare title
$daycolor =   ($commune =~ /(C1[0-9])/) ? "blue" :
   ($dayname[1] =~ /(Quattuor|Feria|Vigilia)/i) ? "black" : 
   ($dayname[1] =~ /duplex/i) ? "red" : 
    "grey"; 
build_comment_line();

#prepare main pages
my $h = $hora;
if ($h =~ /(Ante|Matutinum|Laudes|Prima|Tertia|Sexta|Nona|Vespera|Completorium|Post|Setup)/i)
  {$h = " $1";}
else {$h = '';}
$title = "Divinum Officium$h";
@horas=getdialogcolumn('horas','~',0);

#*** print pages (setup, hora=pray, mainpage)  
  #generate HTML
  htmlHead($title, 2);
    print "<body>\n";

if ($command =~ /setup(.*)/i) {	  
  $pmode = 'setup';
  $command = $1;
  setuptable($command);

} elsif ($command =~ /pray/) {
  $pmode = 'hora';
  $command =~ s/(pray|change|setup)//ig;
  $title = $command;
  $hora = $command;
  if (substr($title,-1) =~ /a/i) {$title .= 'm';}

  $head = ($title =~ /(Ante|Post)/i) ? "$title divinum officium" : "Ad $title";
  $head =~ s/Ad Vesperam/Ad Vesperas/i;
        
  $headline = setheadline();
  headline($head);

	# No background for table cells (Pofficium.pl uses white or horasbg.jpg).
  $background = '';
  ###################
  # Call the function that prints the text of the hour. $command is hour name
  horas($command);

#--- deleted HTML that set HIDDEN INPUT elements for the (now-deleted) FORM
} else {	#mainpage
  $pmode = 'main';
  $command = "";
  $height = floor($screenheight * 4 / 12);
  $height2 = floor($height / 2);

  $headline = setheadline();
  headline($title);
}

#common widgets for main and hora
# These provide links to the various hours and to change the principal
# settings (Versions, Mode, Language 2, Votive [office]). Other settings
# are changed by an options page that sets a cookie.
# Was:    if ($pmode =~ /(main|hora)/i) {
if ($pmode =~ /(main)/i) {
  if ($votive ne 'C9') {
#: ---delete html for links to the various hours
print << "PrintTag";
<P ALIGN=CENTER><I>
<A HREF="Xofficium.pl?date1=$date1&command=prayMatutinum&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
 <FONT COLOR=$hcolor[1]>$horas[1]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&command=prayLaudes&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
<FONT COLOR=$hcolor[2]>$horas[2]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&command=prayPrima&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
<FONT COLOR=$hcolor[3]>$horas[3]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&command=prayTertia&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
<FONT COLOR=$hcolor[4]>$horas[4]</FONT></A>
<BR> 
<A HREF="Xofficium.pl?date1=$date1&command=praySexta&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
<FONT COLOR=$hcolor[5]>$horas[5]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&command=prayNona&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
<FONT COLOR=$hcolor[6]>$horas[6]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&command=prayVespera&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
<FONT COLOR=$hcolor[7]>$horas[7]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&caller=$caller&command=prayCompletorium&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
<FONT COLOR=$hcolor[8]>$horas[8]</FONT></A>
</I></P>
PrintTag
} else {
print << "PrintTag";
<P ALIGN=CENTER><I>
<A HREF="Xofficium.pl?date1=$date1&command=prayMatutinum&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive"><FONT COLOR=$hcolor[1]>$horas[1]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&command=prayLaudes&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive"><FONT COLOR=$hcolor[2]>$horas[2]</FONT></A>
&nbsp;&nbsp; 
<A HREF="Xofficium.pl?date1=$date1&command=prayVesperae&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive"><FONT COLOR=$hcolor[7]>$horas[7]</FONT></A>
&nbsp;&nbsp; 
</I></P>
PrintTag
}

  @chv = splice(@chv, @chv);
  if (-e "$Bin/monastic.pl") {unshift(@versions, 'pre Trident Monastic');}
  for ($i = 0; $i < @versions; $i++) {$chv[$i] = $version =~ /$versions[$i]/ ? 'red' : 'blue';}

  my $vsize = @versions;
  print "<TABLE ALIGN=CENTER BORDER=1><TR><TD ALIGN=CENTER>\n";
  print "<FONT SIZE=1>Versions<BR></FONT>";
  for ($i = 0; $i < @versions; $i++) {
    if ($i > 0) {print "<BR>";}
	print "<A HREF=\"Xofficium.pl?date1=$date1&version=$versions[$i]&testmode=$testmode&lang2=$lang2\&votive=$votive\">" .
    "<FONT COLOR=$chv[$i]>$versions[$i]</FONT></A>";
  }
  print "</TD></TR>\n";


my $sel10 = (!$testmode || $testmode =~ /regular/i) ? 'red' : 'blue';
my $sel11 = ($testmode =~ /Seasonal/i) ? 'red' : 'blue';

  print << "PrintTag";
<TR><TD ALIGN=CENTER VALIGN=MIDDLE>
<FONT SIZE=1>Mode</FONT><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=regular&lang2=$lang2&votive=$votive">
  <FONT COLOR=$sel10>regular</FONT></A><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=seasonal&lang2=$lang2&votive=$votive">
  <FONT COLOR=$sel11>seasonal</FONT></A><BR>
</TD></TR>
PrintTag


$chl1 = ($lang2 =~ /Latin/i) ? 'red' : 'blue';
$chl2 = ($lang2 =~ /English/i) ? 'red' : 'blue';
$chl3 = ($lang2 =~ /Magyar/i) ? 'red' : 'blue';
$sel1 = 'blue'; 
$sel2 = ($votive =~ /C8/) ? 'red' : 'blue';
$sel3 = ($votive =~ /C9/) ? 'red' : 'blue';
$sel4 = ($votive =~ /C12/) ? 'red' : 'blue';
                      
  print << "PrintTag";
<TR><TD ALIGN=CENTER VALIGN=MIDDLE>
<FONT SIZE=1>Language 2</FONT><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=$testmode&lang2=Latin&votive=$votive">
  <FONT COLOR=$chl1>Latin</FONT></A><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=$testmode&lang2=English&votive=$votive">
  <FONT COLOR=$chl2>English</FONT></A><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=$testmode&lang2=Magyar&votive=$votive">
  <FONT COLOR=$chl3>Magyar</FONT></A><BR>
</TD></TR>
<TR><TD ALIGN=CENTER VALIGN=MIDDLE>
<FONT SIZE=1>Votive</FONT><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=$testmode&lang2=$lang2&votive=hodie">
  <FONT COLOR=$sel1>hodie</FONT></A><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=$testmode&lang2=$lang2&votive=C8">
<FONT COLOR=$sel2>Dedication</FONT></A><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=$testmode&lang2=$lang2&votive=C9">
<FONT COLOR=$sel3>Defunctorum</FONT></A><BR>
<A HREF="Xofficium.pl?date1=$date1&version=$version&testmode=$testmode&lang2=$lang2&votive=C12">
<FONT COLOR=$sel4>Parvum B.M.V.</FONT></A><BR>
</TD></TR></TABLE><BR>
<P ALIGN=CENTER><FONT SIZE=-1>
<A HREF="Xofficium.pl?date1=$date1&command=setupparameters&version=$version&testmode=$testmode&lang2=$lang2&votive=$votive">
Options</A>
</FONT>
</P>
PrintTag
}

#common end for programs
  if ($error) {print "<P ALIGN=CENTER><FONT COLOR=red>$error</FONT></P>\n";}
  if ($debug) {print "<P ALIGN=center><FONT COLOR=blue>$debug</FONT></P>\n";}

  $command =~ s/(pray|setup)//ig;

#: deleted HTML for HIDDEN INPUTs to (now-deleted) FORM

# end HTML
print "</body>\n<!-- end\@officiumprog -->\n</html>\n";


#*** headline($head) prints headline for main and pray
sub headline {
  my $head = shift;
  $headline =~ s{!(.*)}{<FONT SIZE=1>$1</FONT>}s;
  my $h = ($hora =~ /(Matutinum|Laudes|Prima|Tertia|Sexta|Nona|Vespera|Completorium)/i) ? $hora : '';
  # stop misspelled hour name from reaching user
	if ($h =~ /Vespera/) {$h = 'Vesperae';}
  print << "PrintTag";
<p align='center' class='header'><span style='color:$daycolor'>$headline<br /></span>
$comment<br /><br />
<span class='bigtext'><span style='color:maroon'>$h</span></span>&nbsp;&nbsp;
$date1
</p>
PrintTag
}

#---dead code?
sub prevnext {
  my $date1 = shift;
  my $inc = shift;

  $date1 =~ s/\//\-/g;
  my ($month,$day,$year) = split('-',$date1);
  
  my $d= date_to_days($day,$month-1,$year);
  
  my @d = days_to_date($d + $inc);
  $month = $d[4]+1;
  $day = $d[3];
  $year = $d[5]+1900;     
  return sprintf("%02i-%02i-%04i", $month, $day, $year);
}

sub checkauth {
  # Don't require auth from localhost (or command line)
  if ($q->url() =~ /http:\/\/localhost/i ||
      $q->url() =~ /http:\/\/1.0.0.127.in-addr.arpa/i) {
    return;
  }

  # calculate what the authentication code should be
  my($authstr) = '';
  foreach $p (sort $q->param) {
    if ($p ne 'auth') {
      if ($authstr ne '') {
        $authstr .= ':';
      }
      my($val) = $q->param($p);
      $authstr .= "$p=$val";
    }
  }
  my($authhex) = hmac_sha256_hex($authstr, $clavis);

  # check it
  my $auth = strictparam('auth');
  if ($auth ne $authhex) {
    # authentication code does not match: return error and exit
    print $q->header(-type  =>  'text/html');
    print $q->start_html("Permission denied"),
          $q->h1("Permission denied");
    # print some explanation
    my $a = '<a href="http://apps.liturgiaetmusica.com">Breviarium Meum</a>';
    print $q->p("This CGI program is not intended to be used directly. $a makes use of it.");
 	  print $q->end_html;
    exit;
  }
}

sub checkMyCal {
	my ($myCalOffice, $myCalRank) = split(/\s/, strictparam('mycal'));

	# Do nothing if the rank is not a decimal number
	if ($myCalRank !~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/) {
		warn "$myCalRank numerum non est.";
		return;
	}
	# Do nothing if the specified office does not exist
	if (! -e "$datafolder/Latin/$myCalOffice") {
		warn "Deest officium '$myCalOffice'. mycal = '$mycal'";
		return;
	}

	# Replace office if rank is superior
	if ($rank < $myCalRank) {
		# Filename of the office to celebrate. e.g. Sancti/08-15.txt
		$winner = $myCalOffice;
		# Numeric rank of the office to celebrate:
		# 6 - I class
		# 5 - II class
		# 3 - III class
		$rank = $myCalRank;

		# TODO: set dayname, handle scripture, commemoration

		# fill winner hashes
		%winner = %{officestring($datafolder, $lang1, $winner)};  
    	%winner2 = %{officestring($datafolder, $lang2, $winner)};
		#dumpCalInfo();
    }
}

sub dumpCalInfo {
	print STDERR "dayname[0] = $dayname[0]\n";
	print STDERR "dayname[1] = $dayname[1]\n";
	#print STDERR "winner hash: @{[ %winner ]}\n";
	print STDERR "winner: $winner\n";
	print STDERR "rank: $rank\n";
	print STDERR "scriptura: $scriptura\n";
}

