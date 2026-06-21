#!/usr/bin/env perl
use strict;
use warnings;

# Fix for all Perl versions: bsd_glob.c references pwd.h, getpwuid(), and
# getpwnam() which are unavailable in WASI (no POSIX passwd database).
# We strip the I_PWD include block and replace the passwd lookups with
# simple fallbacks.

open my $fh, '<', 'ext/File-Glob/bsd_glob.c' or die "Cannot open file: $!";
my @lines = <$fh>;
close $fh;

my @errors;
my @out;
my $i = 0;

# Match a #if / #ifdef / #ifndef directive at the start of a line.
my $RE_IF_DIRECTIVE = qr{^ \s* \# (if|ifdef|ifndef) \b }x;

# Match an #endif directive at the start of a line.
my $RE_ENDIF          = qr{^ \s* \# endif \b }x;

# Match the start of an #ifdef I_PWD block.
my $RE_IFDEF_I_PWD    = qr{^ \s* \# ifdef \s+ I_PWD \b }x;

# Match the start of an #ifdef HAS_PASSWD block.
my $RE_IFDEF_HAS_PWD  = qr{^ \s* \# ifdef \s+ HAS_PASSWD \b }x;

# Detect the getpwuid / DOSISH variant inside a HAS_PASSWD block.
my $RE_HAS_GETPWUID   = qr{ \b getpwuid \b .* \# elif \s+ DOSISH }xs;

# Detect the getpwnam variant inside a HAS_PASSWD block.
my $RE_HAS_GETPWNAM   = qr{ \b getpwnam \b }x;

# ---------------------------------------------------------------------------
# Given the index of a line that starts an #if block, return the index of
# the matching #endif.  Handles nested #if/#ifdef/#ifndef directives.
# ---------------------------------------------------------------------------
sub skip_if_block {
    my ($lines, $start_idx) = @_;
    my $depth = 1;
    my $j = $start_idx;

    while (++$j < @$lines && $depth > 0) {
        $depth++ if $lines->[$j] =~ $RE_IF_DIRECTIVE;
        $depth-- if $lines->[$j] =~ $RE_ENDIF;
    }
    return $j - 1;
}

while ($i < @lines) {
    my $line = $lines[$i];

    # -----------------------------------------------------------------------
    # 1. Strip the entire #ifdef I_PWD ... #endif block (includes pwd.h).
    # -----------------------------------------------------------------------
    if ($line =~ $RE_IFDEF_I_PWD) {
        my $end = skip_if_block(\@lines, $i);
        $i = $end + 1;
        next;
    }

    # -----------------------------------------------------------------------
    # 2. Replace the #ifdef HAS_PASSWD block that uses getpwuid().
    #    This variant has a DOSISH #elif branch; we keep only the DOSISH
    #    body and add a generic #else fallback for non-DOSISH builds.
    # -----------------------------------------------------------------------
    if (   $line =~ $RE_IFDEF_HAS_PWD
        && join("", @lines[$i .. $i + 25]) =~ $RE_HAS_GETPWUID)
    {
        my $end = skip_if_block(\@lines, $i);
        push @out, "#ifdef DOSISH\n";
        push @out, "\t\t\t/* DOSISH fallback */\n";
        push @out, "\t\t\tif ((h = getenv(\"USERPROFILE\")) == NULL) {\n";
        push @out, "\t\t\t    return pattern;\n";
        push @out, "\t\t\t}\n";
        push @out, "#else\n";
        push @out, "                        return pattern;\n";
        push @out, "#endif\n";
        $i = $end + 1;
        next;
    }

    # -----------------------------------------------------------------------
    # 3. Replace the #ifdef HAS_PASSWD block that uses getpwnam().
    #    No DOSISH branch here — just stub it out.
    # -----------------------------------------------------------------------
    if (   $line =~ $RE_IFDEF_HAS_PWD
        && join("", @lines[$i .. $i + 20]) =~ $RE_HAS_GETPWNAM)
    {
        my $end = skip_if_block(\@lines, $i);
        push @out, "return pattern;\n";
        $i = $end + 1;
        next;
    }

    push @out, $line;
    $i++;
}

my $out_str = join("", @out);

# ---------------------------------------------------------------------------
# Post-flight checks: make sure none of the removed symbols leaked through.
# ---------------------------------------------------------------------------
push @errors, "pwd.h include block still present" if $out_str =~ /#ifdef I_PWD/;
push @errors, "getpwuid block not replaced"       if $out_str =~ /getpwuid/;
push @errors, "getpwnam block not replaced"       if $out_str =~ /getpwnam/;

if (@errors) {
    die "Patch failed with " . scalar(@errors) . " error(s):\n"
        . join("\n", @errors) . "\n";
}

open $fh, '>', 'ext/File-Glob/bsd_glob.c' or die "Cannot write file: $!";
print $fh @out;
close $fh;

print "Patch applied successfully.\n";
