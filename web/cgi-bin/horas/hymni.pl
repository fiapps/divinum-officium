# use strict;
# use warnings;

sub gethymn {
  my ($lang) = @_;
  my ($name, $hymn, $hymnsource, $versum, $dname, $cr);
  our ($hora, $version, $vespera, @dayname);
  my $section = translate('Hymnus', $lang);

  if ($hora =~ /matutinum/i) {
    ($hymn, $name) = hymnusmatutinum($lang);
    $hymnsource = 'Matutinum' if (!$hymn);
    $section = '';
  } elsif ($hora =~ /(laudes|vespera)/i) {
    ($hymn, $name) = hymnusmajor($lang);
    $name = "Hymnus $name";
    $hymnsource = 'Major' if (!$hymn);
    $section = "_\n!$section";

    my $ind = ($hora =~ /laudes/i) ? 2 : $vespera;
    ($versum, $cr) = getantvers('Versum', $ind, $lang);
  } else {    # minor hours
    $name = "Hymnus $hora";
    $name =~ s/ / Pasc7 / if ($hora =~ /Tertia/ && $dayname[0] =~ /Pasc7/);

    if ($hora eq 'Completorium' && $version =~ /^Ordo Praedicatorum/) {
      my %ant = %{setupstring($lang, 'Psalterium/Minor Special.txt')};
      $versum = $ant{'Versum 4'};
      postprocess_vr($versum, $lang);
    }
    $hymnsource = 'Minor';
    $section = "#" . $section;
  }

  if ($hymnsource) {
    my %h = %{setupstring($lang, "Psalterium/$hymnsource Special.txt")};
    $hymn = tryoldhymn(\%h, $name, $version);
  }

  if ($hymn =~ /\*/) {    # doxology needed
    my ($dox, $dname) = doxology($lang);
    if ($dname) { $hymn =~ s/\*.*/$dox/s }
    $section .= " {Doxology: $dname}" if ($dname && $section);
  }

  $hymn =~ s/^(?:v\.\s*)?(\p{Lu})/v. $1/;    # add initial
  $hymn =~ s/\*\s*//g;                       # remove star
  $hymn =~ s/_\n(?!!)/_\nr. /g;              # start stropha with red letter

  my $output = "$section\n$hymn";
  $output .= "_\n$versum" if $versum;
  $output;
}

sub hymnusmajor {
  our ($hora, $version, $vespera, @dayname, %winner, $day, $month, $year, $seasonalflag);
  my $lang = shift;
  my $hymn = '';
  my $name = 'Hymnus';
  $name .= checkmtv($version, \%winner) if ($hora =~ /Vespera/i);
  $name = 'Hymnus'
    if (
      (!exists($winner{"$name Vespera"}) && ($vespera == 3 && !exists($winner{"$name Vespera 3"})))
      && (($vespera == 3 && exists($winner{"Hymnus Vespera 3"}))
        || exists($winner{"Hymnus Vespera"}))
    );

  if (hymnshift($version, $day, $month, $year)) {
    $name .= ' Matutinum' if $hora =~ /laudes/i;
    $name .= ' Laudes' if $hora =~ /vespera/i;
    setbuild2("Hymnus shifted");
  } else {
    $name .= " $hora";
  }

  my $cr = 0;

  if ($hora =~ /Vespera/i && $vespera == 3) {
    ($hymn, $cr) = getproprium("$name 3", $lang, $seasonalflag, 1);
  }
  if (!$hymn) { ($hymn, $cr) = getproprium("$name", $lang, $seasonalflag, 1); }

  if (!$hymn) {
    $name = major_getname();
    $name = 'Day0 Laudes2'
      if (
        $name =~ /Day0 Laudes/i
        && ( $dayname[0] =~ /Epi[2-6]/
          || $dayname[0] =~ /Quadp/i
          || $winner{Rank} =~ /(Octobris|Novembris)/i)
      );
  }
  ($hymn, $name);
}

sub doxology {
  our ($version, $rule, @dayname, %winner, %winner2, %commemoratio, $day, $month, $year, $dayofweek);
  return ('', '') if ($version =~ /1960/);

  my $lang = shift;
  my $dox = '';
  my $dname = '';

  if (exists($winner{Doxology})) {
    my %w = (columnsel($lang)) ? %winner : %winner2;
    $dox = $w{Doxology};
    $dname = 'Special';
    setbuild2("Special doxology");
  } else {
    if ($rule && $rule =~ /Doxology=([a-z]+)/i) {
      $dname = $1;
    } elsif (($version =~ /Trident/i || $winner{Rank} !~ /Adventus/)
      && $commemoratio{Rule}
      && $commemoratio{Rule} =~ /Doxology=([a-z]+)/i)
    {
      $dname = $1;
    } elsif (($month == 8 && $day > 15 && $day < 23 && $version !~ /1955|1963/i)
      || ($version !~ /1570|1617/ && $month == 12 && $day > 8 && $day < 16 && $dayofweek > 0))
    {
      $dname = 'Nat';
    } else {
      my $d = ($dayname[0] =~ /Nat/) ? $dayname[0] : "$dayname[0]-$dayofweek";

      if ($d =~ /Nat([0-9]+)/i && ($1 >= 25 || $1 < 6)) {
        $dname = 'Nat';
      } elsif ($d =~ /Nat/i) {
        $dname = 'Epi';
      } elsif ($d =~ /Pasc/i && $d ge 'Pasc1-0' && $d lt 'Pasc5-4') {
        $dname = 'Pasc';
      } elsif ($d =~ /Pasc/i && $d ge 'Pasc5-4' && $d lt 'Pasc7-0') {
        $dname = 'Asc';
      } elsif ($d =~ /Pasc/i && $d ge 'Pasc7-0') {
        $dname = 'Pent';
      }
    }

    if ($dname) {
      my %w = %{setupstring($lang, 'Psalterium/Doxologies.txt')};
      if ($version =~ /Monastic|1570/i && $w{"${dname}T"}) { $dname .= 'T'; }
      $dox = $w{$dname};
      setbuild2("Doxology: $dname");
    }
  }

  ($dox, $dname);
}

1;
