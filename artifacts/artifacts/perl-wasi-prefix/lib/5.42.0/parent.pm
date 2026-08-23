package parent;
use strict;

our $VERSION = '0.244';

sub import {
    my $class = shift;

    my $inheritor = caller(0);

    if ( @_ and $_[0] eq '-norequire' ) {
        shift @_;
    }
    else {
        for ( my @filename = @_ ) {
            local @_;
            s{::|'}{/}g;
            require "$_.pm";
        }
    }

    {
        no strict 'refs';
        push @{"$inheritor\::ISA"}, @_;
    };
}

1;

__END__

