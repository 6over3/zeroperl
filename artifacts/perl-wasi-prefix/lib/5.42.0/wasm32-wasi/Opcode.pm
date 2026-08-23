package Opcode 1.69;

use strict;

use Carp;
use Exporter 'import';
use XSLoader;

sub opset (;@);
sub opset_to_hex ($);
sub opdump (;$);
use subs our @EXPORT_OK = qw(
  opset ops_to_opset
  opset_to_ops opset_to_hex invert_opset
  empty_opset full_opset
  opdesc opcodes opmask define_optag
  opmask_add verify_opset opdump
);

XSLoader::load();

_init_optags();

sub ops_to_opset { opset @_ }

sub opset_to_hex ($) {
    return "(invalid opset)" unless verify_opset( $_[0] );
    unpack( "h*", $_[0] );
}

sub opdump (;$) {
    my $pat = shift;
    foreach ( opset_to_ops(full_opset) ) {
        my $op = sprintf "  %12s  %s\n", $_, opdesc($_);
        next if defined $pat and $op !~ m/$pat/i;
        print $op;
    }
}

sub _init_optags {
    my ( %all, %seen );
    @all{ opset_to_ops(full_opset) } = ();

    local ($_);
    local ($/) = "\n=cut";
    <DATA>;
    $/ = "\n=";
    while (<DATA>) {
        next unless m/^item\s+(:\w+)/;
        my $tag = $1;

        my @lines = grep { m/^\s/ } split(/\n/);
        foreach (@lines) { s/(?:\t|--).*// }
        my @ops = map { split ' ' } @lines;

        foreach (@ops) {
            warn "$tag - $_ already tagged in $seen{$_}\n" if $seen{$_};
            $seen{$_} = $tag;
            delete $all{$_};
        }
        define_optag( $tag, opset(@ops) );
    }
    close(DATA);
    warn "Untagged opnames: " . join( ' ', keys %all ) . "\n" if %all;
}

1;

__DATA__


# the =cut above is used by _init_optags() to get here quickly

