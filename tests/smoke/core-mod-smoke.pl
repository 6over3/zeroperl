#!/usr/bin/perl
# Core module smoke test — exercises core Perl modules via Core::TestMod.
# Prints "CORE_SMOKE_OK" on success, dies with diagnostics on failure.

use strict;
use warnings;
$| = 1;

use Core::TestMod;

print "perl version: $^V\n";

my ($errors, $skipped) = Core::TestMod::run();

if (@$errors) {
    print STDERR "CORE_SMOKE_ERRORS:\n";
    print STDERR "  $_\n" for @$errors;
    exit 1;
}

print "CORE_SMOKE_OK\n";
if (@$skipped) {
    print "CORE_SMOKE_SKIPPED: ", join(', ', @$skipped), "\n";
}
