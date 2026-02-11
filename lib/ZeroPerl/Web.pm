package ZeroPerl::Web;

use strict;
use warnings;
use Exporter 'import';

our $VERSION = '0.01';
our @EXPORT_OK = qw(fetch sleep);

require XSLoader;
XSLoader::load('ZeroPerl::Web', $VERSION);

1;

__END__

=head1 NAME

ZeroPerl::Web - Asynchronous Web APIs for ZeroPerl

=head1 SYNOPSIS

    use ZeroPerl::Web;

    # Fetch data asynchronously (returns a Promise-like behavior via Asyncify)
    my $response = ZeroPerl::Web::fetch("https://api.example.com/data");
    print "Response: $response\n";

    # Sleep asynchronously without blocking the browser main thread
    ZeroPerl::Web::sleep(1000); # Sleep for 1 second

=head1 DESCRIPTION

This module provides access to Web APIs within the ZeroPerl WebAssembly environment.
It uses Asyncify to perform asynchronous operations transparently to Perl code.

=head2 FUNCTIONS

=over 4

=item fetch($url, [\%options])

Performs a network request using the Host's `fetch` API.
Returns the response body as a string.

=item sleep($ms)

Suspends execution for the specified number of milliseconds.
This yields control back to the browser event loop.

=back

=cut
