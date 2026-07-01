package ZeroPerl::Web;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(fetch fetch_json fetch_post sleep);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

require Exporter;

# Bootstrap - call native WASM XS registration
# The xs_init in zeroperl.c registers these via zeroperl_web_bootstrap(__FILE__)

1;
