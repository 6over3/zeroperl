package Time::HiRes;

{ use 5.006; }
use strict;

require Exporter;
use XSLoader ();

our @ISA = qw(Exporter);

our @EXPORT = qw( );
our @EXPORT_OK = qw (usleep sleep ualarm alarm gettimeofday time tv_interval
  getitimer setitimer nanosleep clock_gettime clock_getres
  clock clock_nanosleep
  CLOCKS_PER_SEC
  CLOCK_BOOTTIME
  CLOCK_HIGHRES
  CLOCK_MONOTONIC
  CLOCK_MONOTONIC_COARSE
  CLOCK_MONOTONIC_FAST
  CLOCK_MONOTONIC_PRECISE
  CLOCK_MONOTONIC_RAW
  CLOCK_PROCESS_CPUTIME_ID
  CLOCK_PROF
  CLOCK_REALTIME
  CLOCK_REALTIME_COARSE
  CLOCK_REALTIME_FAST
  CLOCK_REALTIME_PRECISE
  CLOCK_REALTIME_RAW
  CLOCK_SECOND
  CLOCK_SOFTTIME
  CLOCK_THREAD_CPUTIME_ID
  CLOCK_TIMEOFDAY
  CLOCK_UPTIME
  CLOCK_UPTIME_COARSE
  CLOCK_UPTIME_FAST
  CLOCK_UPTIME_PRECISE
  CLOCK_UPTIME_RAW
  CLOCK_VIRTUAL
  ITIMER_PROF
  ITIMER_REAL
  ITIMER_REALPROF
  ITIMER_VIRTUAL
  TIMER_ABSTIME
  d_usleep d_ualarm d_gettimeofday d_getitimer d_setitimer
  d_nanosleep d_clock_gettime d_clock_getres
  d_clock d_clock_nanosleep d_hires_stat
  d_futimens d_utimensat d_hires_utime
  stat lstat utime
);

our $VERSION    = '1.9778';
our $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

our $AUTOLOAD;

sub AUTOLOAD {
    my $constname;
    ( $constname = $AUTOLOAD ) =~ s/.*:://;
    die "&Time::HiRes::constant not defined" if $constname eq 'constant';
    my ( $error, $val ) = constant($constname);
    if ($error) {
        my ( undef, $file, $line ) = caller;
        die "$error at $file line $line.\n";
    }
    {
        no strict 'refs';
        *$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

sub import {
    for my $i ( @_[ 1 .. $#_ ] ) {
        if (   ( $i eq 'clock_getres' && !&d_clock_getres )
            || ( $i eq 'clock_gettime'   && !&d_clock_gettime )
            || ( $i eq 'clock_nanosleep' && !&d_clock_nanosleep )
            || ( $i eq 'clock'           && !&d_clock )
            || ( $i eq 'nanosleep'       && !&d_nanosleep )
            || ( $i eq 'usleep'          && !&d_usleep )
            || ( $i eq 'utime'           && !&d_hires_utime )
            || ( $i eq 'ualarm'          && !&d_ualarm ) )
        {
            require Carp;
            Carp::croak("Time::HiRes::$i(): unimplemented in this platform");
        }
    }
    goto &Exporter::import;
}

XSLoader::load( 'Time::HiRes', $XS_VERSION );

sub tv_interval {
    my ( $a, $b ) = @_;
    $b = [ gettimeofday() ] unless defined($b);
    ( ${$b}[0] - ${$a}[0] ) + ( ( ${$b}[1] - ${$a}[1] ) / 1_000_000 );
}

1;
__END__

