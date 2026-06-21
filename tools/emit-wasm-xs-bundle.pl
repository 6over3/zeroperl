#!/usr/bin/env perl
use strict;
use warnings;

use File::Find qw(find);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Getopt::Long qw(GetOptions);

my $native_prefix;
my $static_ext_file;
my $baseline_file;
my $hints_out;
my $libs_out;
my $xs_init_out;

GetOptions(
    'native-prefix=s'    => \$native_prefix,
    'static-ext-file=s'  => \$static_ext_file,
    'baseline-file=s'    => \$baseline_file,
    'hints-out=s'        => \$hints_out,
    'libs-out=s'         => \$libs_out,
    'xs-init-out=s'      => \$xs_init_out,
) or die "bad options\n";

die "--native-prefix required\n" unless defined $native_prefix;
die "--static-ext-file required\n" unless defined $static_ext_file;
die "--baseline-file required\n" unless defined $baseline_file;
die "--hints-out required\n" unless defined $hints_out;
die "--libs-out required\n" unless defined $libs_out;
die "--xs-init-out required\n" unless defined $xs_init_out;

sub read_lines {
    my ($path) = @_;
    open my $fh, '<', $path or die "open $path: $!";
    my @lines;
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/\s+#.*$//;
        next if $line =~ /^\s*$/;
        push @lines, $line;
    }
    close $fh;
    return @lines;
}

my %wanted;
$wanted{$_} = 1 for read_lines($baseline_file), read_lines($static_ext_file);
my @exts = sort keys %wanted;

my (%archive_for, %has_boot_symbol, %has_archive);
find(
    sub {
        return unless /\.a$/;
        my $archive = $File::Find::name;
        for my $ext (@exts) {
            if ($archive =~ m{/auto/\Q$ext\E/([^/]+\.a)$}) {
                $archive_for{$ext} //= $archive;
                $has_archive{$ext} = 1;
            }
        }
    },
    $native_prefix,
);

my %known_no_boot = map { $_ => 1 } qw(mro);
my @boot_exts = ('DynaLoader');

sub archive_has_symbol {
    my ($archive, $symbol) = @_;
    for my $cmd ('llvm-nm -g', 'nm -g') {
        my $output = qx{$cmd "$archive" 2>/dev/null};
        next if $? != 0;
        return 1 if $output =~ /\b\Q$symbol\E\b/;
    }
    return 0;
}

for my $ext (@exts) {
    if ($has_archive{$ext}) {
        my $boot_symbol = ext_to_boot_symbol($ext);
        if (archive_has_symbol($archive_for{$ext}, $boot_symbol)) {
            push @boot_exts, $ext;
            $has_boot_symbol{$ext} = 1;
            next;
        }
        next if $known_no_boot{$ext};
        die "traced XS extension '$ext' archive '$archive_for{$ext}' is missing expected bootstrap symbol '$boot_symbol'\n";
        next;
    }
    next if $known_no_boot{$ext};
    die "traced XS extension '$ext' has no native static archive or known-no-boot mapping\n";
}

for my $path ($hints_out, $libs_out, $xs_init_out) {
    my $dir = dirname($path);
    make_path($dir) if defined $dir && length $dir && !-d $dir;
}

open my $hints_fh, '>', $hints_out or die "open $hints_out: $!";
print {$hints_fh} "\nstatic_ext='", join(' ', @exts), "'\n";
close $hints_fh;

open my $libs_fh, '>', $libs_out or die "open $libs_out: $!";
for my $ext (sort grep { $archive_for{$_} } keys %archive_for) {
    my $archive = $archive_for{$ext};
    $archive =~ s{^.*?/auto/}{lib/auto/};
    print {$libs_fh} "$archive\n";
}
close $libs_fh;

sub ext_to_boot_symbol {
    my ($ext) = @_;
    return 'boot_DynaLoader' if $ext eq 'DynaLoader';
    (my $symbol = $ext) =~ s{/}{__}g;
    return "boot_$symbol";
}

sub ext_to_boot_name {
    my ($ext) = @_;
    return 'DynaLoader::boot_DynaLoader' if $ext eq 'DynaLoader';
    (my $name = $ext) =~ s{/}{::}g;
    return "$name\::bootstrap";
}

open my $xs_fh, '>', $xs_init_out or die "open $xs_init_out: $!";
for my $ext (@boot_exts) {
    print {$xs_fh} "EXTERN_C void ", ext_to_boot_symbol($ext), "(pTHX_ CV *cv);\n";
}
print {$xs_fh} "\n";
print {$xs_fh} "static void xs_init(pTHX) {\n";
print {$xs_fh} "  static const char file[] = __FILE__;\n";
print {$xs_fh} "  dXSUB_SYS;\n";
print {$xs_fh} "  PERL_UNUSED_CONTEXT;\n\n";
for my $ext (@boot_exts) {
    print {$xs_fh} '  newXS("', ext_to_boot_name($ext), '", ',
      ext_to_boot_symbol($ext), ", file);\n";
}
print {$xs_fh} "}\n";
close $xs_fh;
