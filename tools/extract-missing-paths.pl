#!/usr/bin/env perl
use strict;
use warnings;

my $log = shift @ARGV or die "usage: $0 <runtime-log> [output]\n";
my $out = shift @ARGV;

open my $fh, '<', $log or die "open $log: $!";
my %seen;
while (my $line = <$fh>) {
    while ($line =~ /Can't locate ([A-Za-z0-9_\/.-]+\.(?:pm|pl))/g) {
        $seen{$1} = 1;
    }
}
close $fh;

my @paths = sort keys %seen;
if (defined $out) {
    open my $ofh, '>', $out or die "open $out: $!";
    print {$ofh} "$_\n" for @paths;
    close $ofh;
}
else {
    print "$_\n" for @paths;
}
