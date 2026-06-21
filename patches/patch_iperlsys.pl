#!/usr/bin/env perl
use strict;
use warnings;

# Fix for Perl <=5.18: iperlsys.h defines PerlProc_setuid/setgid with plain
# setuid/setgid calls, but WASI's gid_t/uid_t are 32-bit while Perl passes UV
# (64-bit).  This causes wasm-ld signature mismatch.  We add explicit casts.
#
# Only the single-line macro definitions are touched; multi-line variants that
# end with backslash are left untouched.

my $file = 'iperlsys.h';
open my $fh, '<', $file or die "Cannot read $file: $!";
my $content = do { local $/; <$fh> };
close $fh;

my $replaced = 0;

# Match exactly:
#   #define PerlProc_setgid(g)<ws>setgid((g))
# and replace setgid((g)) with setgid((Gid_t)(g)), preserving whitespace.
$replaced++ if $content =~ s/^(#\s*define\s+PerlProc_setgid\(g\))(\s+)setgid\(\(g\)\)$/${1}${2}setgid((Gid_t)(g))/m;

# Same for setuid.
$replaced++ if $content =~ s/^(#\s*define\s+PerlProc_setuid\(u\))(\s+)setuid\(\(u\)\)$/${1}${2}setuid((Uid_t)(u))/m;

if ($replaced != 2) {
    die "iperlsys.h patch expected 2 replacements, got $replaced. "
        . "The macro format may have changed.\n";
}

open $fh, '>', $file or die "Cannot write $file: $!";
print $fh $content;
close $fh;

print "iperlsys.h patch applied successfully ($replaced replacements).\n";
