#!/usr/bin/env perl
use strict;
use warnings;

# Fix for Perl ≤5.18: mg_vtable.pl is missing vtable entries for vstring,
# amagic, and amagicelem magic types.  These exist in the C source but
# the regen script does not emit them, causing undefined symbol errors
# when linking XS modules that reference PL_vtbl_vstring / PL_vtbl_amagic.
# This was fixed in 5.20+ by adding the entries upstream.

my $dir = $ENV{WASM_DIR} || '/build/wasm';
my $f   = "$dir/regen/mg_vtable.pl";

open my $fh, '<', $f or die "Cannot open $f: $!";
my $c = do { local $/; <$fh> };
close $fh;

# ---------------------------------------------------------------------------
# 1. Add vtable => 'vstring' to the vstring magic definition.
#
#    Before:  vstring => { char => 'V', value_magic => 1
#    After:   vstring => { char => 'V', vtable => 'vstring', value_magic => 1
# ---------------------------------------------------------------------------
$c =~ s{
    (                           # $1 - prefix to keep
        vstring \s* => \s* \{ \s*
        char \s* => \s* 'V' , \s*
    )
    (                           # $2 - suffix to keep
        value_magic \s* => \s* 1
    )
}{${1}vtable => 'vstring', $2}x;

# ---------------------------------------------------------------------------
# 2. Insert amagic / amagicelem entries before the "overload" entry.
#
#    The mg_vtable.pl file contains a placeholder comment about where the
#    old overload magic used to live.  We splice two new magic entries
#    (amagic and amagicelem) between that comment and the real overload
#    definition that follows it.
# ---------------------------------------------------------------------------
$c =~ s{
    (                           # $1 - original comment line
        \# \s* overload, \s* or \s* type \s* "A" \s* magic, \s* used \s* to \s* be \s* here .*? \n
    )
    ( \s+ overload )            # $2 - the "overload" entry that follows
}{
$1     amagic => { char => 'A', vtable => 'amagic', desc => 'AMG hash' },
     amagicelem => { char => 'a', vtable => 'amagicelem', desc => 'AMG element' },
$2
}sx;

# ---------------------------------------------------------------------------
# 3. Add empty placeholder entries for vstring, amagic, and amagicelem
#    immediately after the destruct entry.
#
#    Before:  'destruct' => {free => 'freedestruct'},
#    After:   'destruct' => {free => 'freedestruct'},
#             'vstring' => {},
#             'amagic' => {},
#             'amagicelem' => {},
# ---------------------------------------------------------------------------
$c =~ s{
    (                           # $1 - the destruct line to keep
        'destruct' \s* => \s* \{ free \s* => \s* 'freedestruct' \} ,
    )
}{$1
     'vstring' => {},
     'amagic' => {},
     'amagicelem' => {},
}x;

open $fh, '>', $f or die "Cannot write $f: $!";
print $fh $c;
close $fh;

system 'perl', $f;
