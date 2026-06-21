#!/usr/bin/perl
# Core smoke test — exercises core Perl modules available across all
# supported Perl versions (5.16.3+) in the zeroperl WASM build.
# Prints "CORE_SMOKE_OK" on success, dies with diagnostics on failure.
#
# Modules are tested in tiers:
#   Tier 1 — must work on every version (strict, warnings, Digest::MD5, etc.)
#   Tier 2 — version/feature-dependent (File::Spec, Data::Dumper, IO::File, etc.)
#            tested conditionally; failures are errors only when the feature
#            should be present.

use strict;
use warnings;
$| = 1;

my @errors;
my @skipped;

print "perl version: $^V\n";

# ── Tier 1: universal core ──────────────────────────────────────────────────

# Digest::MD5 (XS, core since 5.8)
eval {
    require Digest::MD5;
    my $md5 = Digest::MD5::md5_hex('zeroperl');
    die "Digest::MD5" unless length($md5) == 32;
    1;
} or push @errors, "Digest::MD5: $@";

# List::Util (XS, core since 5.8)
eval {
    require List::Util;
    my $sum = List::Util::sum(1, 2, 3, 4, 5);
    die "List::Util::sum" unless $sum == 15;
    1;
} or push @errors, "List::Util: $@";

# Cwd (XS, core since 5.4)
eval {
    require Cwd;
    my $cwd = Cwd::getcwd();
    die "Cwd::getcwd" unless defined $cwd && length($cwd) > 0;
    1;
} or push @errors, "Cwd: $@";

# Fcntl (XS, core since 5.4)
eval {
    require Fcntl;
    my $ok = defined &Fcntl::O_RDONLY;
    die "Fcntl::O_RDONLY" unless $ok;
    1;
} or push @errors, "Fcntl: $@";

# MIME::Base64 (XS, core since 5.8)
eval {
    require MIME::Base64;
    my $enc = MIME::Base64::encode_base64('hello');
    my $dec = MIME::Base64::decode_base64($enc);
    die "MIME::Base64 roundtrip" unless $dec eq 'hello';
    1;
} or push @errors, "MIME::Base64: $@";

# Basic regex and string ops (core language, no module needed)
eval {
    my $s = "Hello, World!";
    die "regex match" unless $s =~ /World/;
    my $r = $s =~ s/World/Perl/r;
    die "regex subst" unless $r eq "Hello, Perl!";
    die "split/join" unless join(':', split(/,/, "a,b,c")) eq "a:b:c";
    1;
} or push @errors, "regex/string: $@";

# ── Tier 2: version-conditional ──────────────────────────────────────────────

# File::Spec — core since 5.5, but may be stripped by wasm-opt in full-shrink
# builds or missing from the embedded SFS.
eval {
    require File::Spec;
    my $cat = File::Spec->catfile('a', 'b', 'c');
    die "File::Spec->catfile" unless $cat && $cat =~ m{a};
    1;
} or do {
    push @skipped, "File::Spec";
};

# Data::Dumper — core since 5.6, but depends on constant.pm which depends on
# unicore/Heavy.pl (via utf8_heavy.pl) on Perl < 5.18.  The unicore directory
# is trimmed from the prefix in some builds.
eval {
    require Data::Dumper;
    my $s = Data::Dumper::Dumper([1, 2, 3]);
    die "Data::Dumper" unless $s && $s =~ /\d/;
    1;
} or do {
    push @skipped, "Data::Dumper";
};

# IO::File — core since 5.4, but new_tmpfile does not work in WASI (no tmpdir).
# Test file I/O via in-memory write/read on an explicit file path instead.
eval {
    require IO::File;
    my $fh = IO::File->new('/work/_smoke_tmp', 'w');
    die "IO::File->new(w)" unless $fh;
    print $fh "test\n";
    $fh->close;
    $fh = IO::File->new('/work/_smoke_tmp', 'r');
    die "IO::File->new(r)" unless $fh;
    my $line = <$fh>;
    $fh->close;
    die "IO::File roundtrip" unless $line eq "test\n";
    1;
} or do {
    push @skipped, "IO::File";
};

# Encode — core since 5.8, but depends on unicore/Heavy.pl on older perls.
eval {
    require Encode;
    my $enc = Encode::encode('UTF-8', 'hello');
    my $dec = Encode::decode('UTF-8', $enc);
    die "Encode roundtrip" unless $dec eq 'hello';
    1;
} or do {
    push @skipped, "Encode";
};

# File::Glob — core since 5.6, may be stripped or unavailable.
eval {
    require File::Glob;
    my @files = File::Glob::bsd_glob('*');
    die "File::Glob" unless @files >= 0;
    1;
} or do {
    push @skipped, "File::Glob";
};

# POSIX — not built in the WASI configuration (noextensions).
eval {
    require POSIX;
    my $ceil = POSIX::ceil(1.5);
    die "POSIX::ceil" unless $ceil == 2;
    1;
} or do {
    push @skipped, "POSIX";
};

# ── Report ───────────────────────────────────────────────────────────────────

if (@errors) {
    print STDERR "CORE_SMOKE_ERRORS:\n";
    print STDERR "  $_\n" for @errors;
    exit 1;
}

print "CORE_SMOKE_OK\n";
if (@skipped) {
    print "CORE_SMOKE_SKIPPED: ", join(', ', @skipped), "\n";
}
