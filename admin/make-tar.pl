#!/usr/bin/perl

use Archive::Tar;

if (scalar(@ARGV) != 3) {
  die "usage: $0 <commit> <path> <changed-files.tgz>"
}

my $commit = @ARGV[0];
my $path = @ARGV[1];
my $outfile = @ARGV[2];

@diffFiles = `git diff --name-status --relative '$commit' '$path'`;

if (scalar(@diffFiles) == 0) {
  die "No changed files found\n";
}

my @deletedFiles;
my @changedFiles;
foreach $line (@diffFiles) {
  if ($line =~ /(\S)\s+(\S.*\S)\s*$/) {
    my $change = $1;
    my $filename = $2;
    if ($change =~ /D/) {
      push(@deletedFiles, $filename);
    } elsif ($change =~ /[AM]/) {
      push(@changedFiles, $filename);
    } else {
      die "unrecognized changed type '$change' to '$filename'\n";
    }
  } else {
    chomp $line;
    die "Failed to parse '$line'\n";
  }
}

# Create a tarball of new or updated files
if (@changedFiles > 0) {
  my $tar = Archive::Tar->new;
  $tar->add_files(@changedFiles);
  $tar->write($outfile);
  print "Wrote ", scalar(@changedFiles), " new or changed files to '$outfile'\n";
}

# Tell user to manually delete deleted files
if (@deletedFiles > 0) {
  print "You must manually delete the following files to apply the diff:\n";
  foreach $filename (@deletedFiles) {
    print "  $filename\n";
  }
}
