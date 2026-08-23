package Config::Extensions;
use strict;
our ( %Extensions, $VERSION, @ISA, @EXPORT_OK );
use Config;
require Exporter;

$VERSION   = '0.03';
@ISA       = 'Exporter';
@EXPORT_OK = '%Extensions';

foreach my $type (qw(static dynamic nonxs)) {
    foreach ( split /\s+/, $Config{ $type . '_ext' } ) {
        s!/!::!g;
        $Extensions{$_} = $type;
    }
}

1;
__END__

