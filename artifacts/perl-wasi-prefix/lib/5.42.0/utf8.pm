package utf8;

use strict;
use warnings;

our $utf8_hint_bits  = 0x00800000;
our $ascii_hint_bits = 0x00000010;

our $VERSION = '1.27';
our $AUTOLOAD;

sub import {
    $^H |= $utf8_hint_bits;
    $^H &= ~$ascii_hint_bits;
}

sub unimport {
    $^H &= ~$utf8_hint_bits;
}

sub AUTOLOAD {
    goto &$AUTOLOAD if defined &$AUTOLOAD;
    require Carp;
    Carp::croak("Undefined subroutine $AUTOLOAD called");
}

1;
__END__

