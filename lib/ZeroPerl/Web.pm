package ZeroPerl::Web;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(fetch fetch_json fetch_post sleep);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

require XSLoader;
XSLoader::load('ZeroPerl::Web');

1;

__END__

=head1 NAME

ZeroPerl::Web - Async Web APIs for zeroperl

=head1 SYNOPSIS

    use ZeroPerl::Web qw(:all);
    
    # HTTP GET
    my $data = fetch("https://api.example.com/data");
    
    # HTTP GET (JSON endpoint)
    my $json = fetch_json("https://api.example.com/data.json");
    
    # HTTP POST
    my $result = fetch_post("https://api.example.com/submit",
        '{"key": "value"}', "application/json");
    
    # Non-blocking sleep
    sleep(0.5);  # 500ms

=head1 DESCRIPTION

ZeroPerl::Web provides asynchronous web API access for Perl code
running inside zeroperl (WebAssembly). It bridges Perl to the
JavaScript host environment via WASM imports.

=head1 FUNCTIONS

=head2 fetch($url)

Performs an HTTP GET request. Returns the response body as a string,
or undef on error.

=head2 fetch_json($url)

Performs an HTTP GET request, returns raw JSON text.
(Use C<decode_json> from L<JSON> to parse it.)

=head2 fetch_post($url, $body, $content_type)

Performs an HTTP POST request. Returns the response body.

=head2 sleep($seconds)

Non-blocking sleep. Uses asyncify to yield the WASM runtime,
allowing other operations to proceed during the sleep period.

=cut
