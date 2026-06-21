#!/usr/bin/env perl
use strict;
use warnings;

# Fix for Perl 5.28.x: lc_numeric_set is declared inside #ifdef USE_LOCALE_NUMERIC
# but used unconditionally at the end of Perl_sv_vcatpvfn_flags.
# This was fixed in 5.30+ by wrapping the usage in #ifdef USE_LOCALE_NUMERIC.

my $f = 'sv.c';
open my $fh, '<', $f or die "Cannot open $f: $!";
my $c = do { local $/; <$fh> };
close $fh;

# ---------------------------------------------------------------------------
# Wrap the unconditional lc_numeric_set block at the end of
# Perl_sv_vcatpvfn_flags in #ifdef USE_LOCALE_NUMERIC.
#
# The block looks like:
#     if (lc_numeric_set) {
#         RESTORE_LC_NUMERIC();   /* Done outside loop, so don't have to
#                                    save/restore each iteration. */
#     }
# ---------------------------------------------------------------------------
$c =~ s{
    (                           # $1 - the entire block to wrap
        \n
        \s{4} if \s* \( lc_numeric_set \) \s* \{ \n
        \s{8} RESTORE_LC_NUMERIC \(\) ;
        .*?                     # swallow the multi-line comment
        save/restore \s+ each \s+ iteration\. \s* \*/ \n
        \s{4} \}
    )
}{#ifdef USE_LOCALE_NUMERIC$1\n#endif}sx;

open $fh, '>', $f or die "Cannot write $f: $!";
print $fh $c;
close $fh;

print "sv.c locale patch applied successfully.\n";
