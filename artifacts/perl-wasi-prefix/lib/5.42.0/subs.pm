package subs;

use strict;
use warnings;

our $VERSION = '1.04';


sub import {
    my $callpack = caller;
    my $pack     = shift;
    my @imports  = @_;
    foreach my $sym (@imports) {
        no strict 'refs';
        *{"${callpack}::$sym"} = \&{"${callpack}::$sym"};
    }
}

1;
