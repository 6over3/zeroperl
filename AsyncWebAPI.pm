package AsyncWebAPI;

use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('AsyncWebAPI', $VERSION);

1;
__END__

=head1 NAME

AsyncWebAPI - Perl bindings for asynchronous Web APIs in zeroperl

=head1 SYNOPSIS

  use AsyncWebAPI;
  
  # Asynchronous HTTP Fetch
  my $response = AsyncWebAPI::fetch("https://api.github.com/zen");
  print "GitHub says: $response\n";
  
  # Asynchronous Sleep
  AsyncWebAPI::sleep(5); # sleep for 5 seconds asynchronously

=head1 DESCRIPTION

This module implements bindings for async web APIs such as fetch and sleep, using
Binaryen's Asyncify stack-unwinding/rewinding mechanism to yield execution back
to the host environment and resume when the host async call resolves.

=cut
