#!/usr/bin/env perl
use strict;
use warnings;

use File::Find qw(find);
use File::Spec;

my $root = shift @ARGV or die "usage: $0 <perl-lib-root>\n";
my @targets = grep { -d $_ } (
    File::Spec->catdir($root, 'wasm32-wasi'),
    File::Spec->catdir($root, 'unicore'),
);

exit 0 unless @targets;

find(
    sub {
        return unless -f $_;
        return unless $File::Find::name =~ m{/unicore/.*\.pl$};
        if ($_ eq 'TestProp.pl') {
            unlink $File::Find::name or die "unlink $File::Find::name: $!";
            return;
        }
        open my $in, '<', $File::Find::name or die "open $File::Find::name: $!";
        my @out;
        while (my $line = <$in>) {
            next if $line =~ /^\s*#/;
            next if $line =~ /^\s*$/;
            push @out, $line;
        }
        close $in;
        open my $out, '>', $File::Find::name or die "open $File::Find::name: $!";
        print {$out} @out;
        close $out;
    },
    @targets,
);
