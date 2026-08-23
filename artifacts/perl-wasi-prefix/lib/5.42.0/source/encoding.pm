package source::encoding;

use v5.40;

our $VERSION = '0.01';

our $ascii_hint_bits = 0x00000010;

sub import {
    unimport();
    my ( undef, $arg ) = @_;
    if ( $arg eq 'utf8' ) {
        require utf8;
        utf8->import;
        return;
    }
    elsif ( $arg eq 'ascii' ) {
        $^H |= $ascii_hint_bits;
        return;
    }

    die "Bad argument for source::encoding: '$arg'";
}

sub unimport {
    $^H &= ~$ascii_hint_bits;
    utf8->unimport;
}

1;
__END__

