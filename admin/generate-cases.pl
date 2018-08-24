#!/usr/bin/perl -w

# Invoke divinum-get.pl repeatedly to generate test cases for the breviary.

use Getopt::Long;
use Date::Calc
    qw/check_date Date_to_Days Add_Delta_Days Decode_Date_US Today/;

my $divinumGet = 'perl admin/divinum-get.pl';

my @prayers = qw/Matutinum Laudes Prima Tertia Sexta Nona Vespera Completorium/;
my $prayers = join(' ', @prayers);

my @versions = (
    'Trident 1570',
    'Trident 1910',
    'Divino Afflatu',
    'Reduced 1955',
    'Rubrics 1960'
);
my $versions = join('|', @versions);
my $version = "Rubrics 1960"; # default

my @params = qw/accented browsertime caller expand expandnum lang1 lang2 local
                notes priest screenheight searchvalue setup testmode votive/;
my $params = join(' ', @params);

my ($y, $m, $d) = Today();
my $prayer;
my $from = "$m-$d-$y";
my $to;

my $query;
my @cgi = ();
my $dir;
my $base_url = 'https://bmbe.liturgiaetmusica.com/cgi-bin';
my $suppress_timestamp;

my $help;

my $USAGE = <<USAGE ;
Establish divinumofficium web results for a given hour and a range of dates.
Usage: divinum-get [--prayer=PRAYER|--query=QUERY] [option...]

Options:
--prayer=PRAYER     retrieve an Hour of the Divine Office, or the Mass
--version=VERSION   rubric version [no default]
--from=MM-DD-YYYY   start downloading for this date [default: $from]
--to=MM-DD-YYYY     end downloading for this date [default: from-date]

--query=QUERY       retrieve BASE/QUERY
--cgi=PARAM=VALUE   query parameters passed directly as PARAM=VALUE&PARAM=VALUE...

--dir=DIR           put downloads into directory DIR [default: current directory]
--url=BASE          base URL of site to download from [default: $base_url]
--no-timestamp      suppress timestamp in test files

--help              This.

PRAYER              all [$prayers]
VERSION             [$versions]
VERSION can be abbreviated as long as it's unambiguous.
QUERY               Any HTTP subquery, possibly including (CGI) query parameters
PARAM               [$params]
                    or anything else (unchecked)
VALUE               anything
PARAM=VALUE may need to be escaped or quoted from the shell.
Both PARAM and VALUE will be urlencoded for transmission.

Download files are named by the hora and date and version; or by the entry if specified.
To replay tests use divinum-replay.

Note: the default URL is the live site. The default for divinum-replayh is the 
environment variable DIVINUM_OFFICIUM_URL.  This allows -get to establish live results
and -replay to test against a test site.
USAGE

GetOptions(
    'prayer=s' => \$prayer,
    'version=s' => \$version,
    'from=s' => \$from,
    'to=s' => \$to,

    'query=s' => \$query,
    'cgi=s' => \@cgi,

    'dir=s' => \$dir,
    'url=s' => \$base_url,

    'no-timestamp' => \$suppress_timestamp,

    'help' => \$help
) or die $USAGE;

if ( $help )
{
    print STDOUT $USAGE;
    exit 0;
}

die "Specify --prayer\n" unless $prayer;

my $cmd;

# Check arguments and set up defaults
die "Invalid date $from .\n" unless my ($y1,$m1,$d1) = Decode_Date_US($from);
$to = $from unless $to;
die "Invalid date $to .\n" unless my ($y2,$m2,$d2) = Decode_Date_US($to);
die "Start date must be before end date.\n" unless Date_to_Days($y1,$m1,$d1) <= Date_to_Days($y2,$m2,$d2);

$cmd = $divinumGet . " --url=$base_url --from=$from --to=$to '--version=$version'";
if ($query) {
  $cmd .= " --query=$query"
}
foreach $arg (@cgi) {
  $cmd .= " --cgi=$arg"
}
if ($dir) {
  $cmd .= " --dir=$dir"
}
if ($suppress_timestamp) {
  $cmd .= " --no-timestamp"
}

# Invoke $cmd for all horae or one hora.
my @horae = qw/Matutinum Laudes Prima Tertia Sexta Nona Vespera Completorium/;
if ($prayer eq 'all') {
  foreach $hora (@horae) {
    system("$cmd --prayer=$hora");
  }
} else {
  $cmd .= " --prayer=$prayer";
  system("$cmd");
}
