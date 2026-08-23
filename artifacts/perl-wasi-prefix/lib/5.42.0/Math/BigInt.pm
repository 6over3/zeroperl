
package Math::BigInt;

use 5.006001;
use strict;
use warnings;

use Carp         qw< carp croak >;
use Scalar::Util qw< blessed refaddr >;

our $VERSION = '2.005002';
$VERSION =~ tr/_//d;

require Exporter;
our @ISA       = qw< Exporter >;
our @EXPORT_OK = qw< objectify bgcd blcm >;

use overload

  '+' => sub { $_[0]->copy()->badd( $_[1] ); },

  '-' => sub {
    my $c = $_[0]->copy();
    $_[2]
      ? $c->bneg()->badd( $_[1] )
      : $c->bsub( $_[1] );
  },

  '*' => sub { $_[0]->copy()->bmul( $_[1] ); },

  '/' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bdiv( $_[0] )
      : $_[0]->copy()->bdiv( $_[1] );
  },

  '%' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bmod( $_[0] )
      : $_[0]->copy()->bmod( $_[1] );
  },

  '**' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bpow( $_[0] )
      : $_[0]->copy()->bpow( $_[1] );
  },

  '<<' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bblsft( $_[0] )
      : $_[0]->copy()->bblsft( $_[1] );
  },

  '>>' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bbrsft( $_[0] )
      : $_[0]->copy()->bbrsft( $_[1] );
  },

  '+=' => sub { $_[0]->badd( $_[1] ); },

  '-=' => sub { $_[0]->bsub( $_[1] ); },

  '*=' => sub { $_[0]->bmul( $_[1] ); },

  '/=' => sub { scalar $_[0]->bdiv( $_[1] ); },

  '%=' => sub { $_[0]->bmod( $_[1] ); },

  '**=' => sub { $_[0]->bpow( $_[1] ); },

  '<<=' => sub { $_[0]->bblsft( $_[1] ); },

  '>>=' => sub { $_[0]->bbrsft( $_[1] ); },

  '<' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->blt( $_[0] )
      : $_[0]->blt( $_[1] );
  },

  '<=' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->ble( $_[0] )
      : $_[0]->ble( $_[1] );
  },

  '>' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bgt( $_[0] )
      : $_[0]->bgt( $_[1] );
  },

  '>=' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bge( $_[0] )
      : $_[0]->bge( $_[1] );
  },

  '==' => sub { $_[0]->beq( $_[1] ); },

  '!=' => sub { $_[0]->bne( $_[1] ); },

  '<=>' => sub {
    my $cmp = $_[0]->bcmp( $_[1] );
    defined($cmp) && $_[2] ? -$cmp : $cmp;
  },

  'cmp' => sub {
    $_[2]
      ? "$_[1]" cmp $_[0]->bstr()
      : $_[0]->bstr() cmp "$_[1]";
  },

  '&' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->band( $_[0] )
      : $_[0]->copy()->band( $_[1] );
  },

  '&=' => sub { $_[0]->band( $_[1] ); },

  '|' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bior( $_[0] )
      : $_[0]->copy()->bior( $_[1] );
  },

  '|=' => sub { $_[0]->bior( $_[1] ); },

  '^' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bxor( $_[0] )
      : $_[0]->copy()->bxor( $_[1] );
  },

  '^=' => sub { $_[0]->bxor( $_[1] ); },

  'neg' => sub { $_[0]->copy()->bneg(); },

  '~' => sub { $_[0]->copy()->bnot(); },

  '++' => sub { $_[0]->binc() },

  '--' => sub { $_[0]->bdec() },

  'atan2' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->batan2( $_[0] )
      : $_[0]->copy()->batan2( $_[1] );
  },

  'cos' => sub { $_[0]->copy()->bcos(); },

  'sin' => sub { $_[0]->copy()->bsin(); },

  'exp' => sub { $_[0]->copy()->bexp( $_[1] ); },

  'abs' => sub { $_[0]->copy()->babs(); },

  'log' => sub { $_[0]->copy()->blog(); },

  'sqrt' => sub { $_[0]->copy()->bsqrt(); },

  'int' => sub { $_[0]->copy()->bint(); },

  'bool' => sub { $_[0]->is_zero() ? '' : 1; },

  '""' => sub { $_[0]->bstr(); },

  '0+' => sub { $_[0]->numify(); },

  '=' => sub { $_[0]->copy(); },

  ;

our $accuracy  = undef;
our $precision = undef;

our $round_mode = 'even';
our $div_scale  = 40;

our $upgrade   = undef;
our $downgrade = undef;

our $_trap_nan = 0;
our $_trap_inf = 0;

my $nan = 'NaN';

my $DEFAULT_LIB = 'Math::BigInt::Calc';
my $LIB;

my $IMPORT = 0;

our $rnd_mode = 'even';

sub TIESCALAR {
    my ($class) = @_;
    bless \$round_mode, $class;
}

sub FETCH {
    return $round_mode;
}

sub STORE {
    $rnd_mode = ( ref $_[0] )->round_mode( $_[1] );
}

BEGIN {
    tie $rnd_mode, 'Math::BigInt';

    *is_pos    = \&is_positive;
    *is_neg    = \&is_negative;
    *as_number = \&as_int;
}

sub accuracy {
    my $x     = shift;
    my $class = ref($x) || $x || __PACKAGE__;

    if (@_) {
        my $a = shift;

        if ( defined $a ) {
            $a = $a->can('numify') ? $a->numify() : 0 + "$a" if ref($a);
            croak "accuracy must be a number, not '$a'"
              if $a !~ /^\s*[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?\s*\z/;
            croak "accuracy must be an integer, not '$a'"
              if $a != int $a;
        }

        if ( ref($x) ) {
            $x->bround($a) if defined $a;
            $x->{precision} = undef;
            $x->{accuracy}  = $a;
        }
        else {
            no strict 'refs';
            ${"${class}::precision"} = undef;
            ${"${class}::accuracy"}  = $a;
        }
    }

    else {
        if ( ref($x) ) {
            return $x->{accuracy};
        }
        else {
            no strict 'refs';
            return ${"${class}::accuracy"};
        }
    }
}

sub precision {
    my $x     = shift;
    my $class = ref($x) || $x || __PACKAGE__;

    if (@_) {
        my $p = shift;

        if ( defined $p ) {
            $p = $p->can('numify') ? $p->numify() : 0 + "$p" if ref($p);
            croak "precision must be a number, not '$p'"
              if $p !~ /^\s*[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?\s*\z/;
            croak "precision must be an integer, not '$p'"
              if $p != int $p;
        }

        if ( ref($x) ) {
            $x->bfround($p) if defined $p;
            $x->{accuracy}  = undef;
            $x->{precision} = $p;
        }
        else {
            no strict 'refs';
            ${"${class}::accuracy"}  = undef;
            ${"${class}::precision"} = $p;
        }
    }

    else {
        if ( ref($x) ) {
            return $x->{precision};
        }
        else {
            no strict 'refs';
            return ${"${class}::precision"};
        }
    }
}

sub round_mode {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if (@_) {
        my $m = shift;
        croak("The value for 'round_mode' must be defined")
          unless defined $m;
        croak("Unknown round mode '$m'")
          unless $m =~ /^(even|odd|\+inf|\-inf|zero|trunc|common)$/;

        if ( ref($self) && exists $self->{round_mode} ) {
            $self->{round_mode} = $m;
        }
        else {
            no strict 'refs';
            ${"${class}::round_mode"} = $m;
        }
    }

    else {
        if ( ref($self) && exists $self->{round_mode} ) {
            return $self->{round_mode};
        }
        else {
            no strict 'refs';
            my $m = ${"${class}::round_mode"};
            return defined($m) ? $m : $round_mode;
        }
    }
}

sub div_scale {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if (@_) {
        my $f = shift;
        croak("The value for 'div_scale' must be defined") unless defined $f;
        $f = $f->can('numify') ? $f->numify() : 0 + "$f" if ref($f);
        croak "div_scale must be a number, not '$f'"
          unless $f =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?\z/;
        croak "div_scale must be an integer, not '$f'"
          if $f != int $f;
        croak "div_scale must be positive, not '$f'" if $f < 0;

        if ( ref($self) && exists $self->{div_scale} ) {
            $self->{div_scale} = $f;
        }
        else {
            no strict 'refs';
            ${"${class}::div_scale"} = $f;
        }
    }

    else {
        if ( ref($self) && exists $self->{div_scale} ) {
            return $self->{div_scale};
        }
        else {
            no strict 'refs';
            my $f = ${"${class}::div_scale"};
            return defined($f) ? $f : $div_scale;
        }
    }
}

sub trap_inf {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if (@_) {
        my $b = shift() ? 1 : 0;
        if ( ref($self) && exists $self->{trap_inf} ) {
            $self->{trap_inf} = $b;
        }
        else {
            no strict 'refs';
            ${"${class}::_trap_inf"} = $b;
        }
    }

    else {
        if ( ref($self) && exists $self->{trap_inf} ) {
            return $self->{trap_inf};
        }
        else {
            no strict 'refs';
            return ${"${class}::_trap_inf"};
        }
    }
}

sub trap_nan {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if (@_) {
        my $b = shift() ? 1 : 0;
        if ( ref($self) && exists $self->{trap_nan} ) {
            $self->{trap_nan} = $b;
        }
        else {
            no strict 'refs';
            ${"${class}::_trap_nan"} = $b;
        }
    }

    else {
        if ( ref($self) && exists $self->{trap_nan} ) {
            return $self->{trap_nan};
        }
        else {
            no strict 'refs';
            return ${"${class}::_trap_nan"};
        }
    }
}

sub upgrade {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if (@_) {
        my $u = shift;
        if ( ref($self) && exists $self->{upgrade} ) {
            $self->{upgrade} = $u;
        }
        else {
            no strict 'refs';
            ${"${class}::upgrade"} = $u;
        }
    }

    else {
        if ( ref($self) && exists $self->{upgrade} ) {
            return $self->{upgrade};
        }
        else {
            no strict 'refs';
            return ${"${class}::upgrade"};
        }
    }
}

sub downgrade {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if (@_) {
        my $d = shift;
        if ( ref($self) && exists $self->{downgrade} ) {
            $self->{downgrade} = $d;
        }
        else {
            no strict 'refs';
            ${"${class}::downgrade"} = $d;
        }
    }

    else {
        if ( ref($self) && exists $self->{downgrade} ) {
            return $self->{downgrade};
        }
        else {
            no strict 'refs';
            return ${"${class}::downgrade"};
        }
    }
}

sub modify () {

    0;
}

sub config {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if ( @_ > 1 || ( @_ == 1 && ( ref( $_[0] ) eq 'HASH' ) ) ) {

        my $args = ref( $_[0] ) eq 'HASH' ? { %{ $_[0] } } : {@_};

        croak "config(): both accuracy and precision are defined"
          if defined( $args->{accuracy} ) && defined( $args->{precision} );

        if ( defined $args->{accuracy} ) {
            $self->accuracy( $args->{accuracy} );
        }
        elsif ( defined $args->{precision} ) {
            $self->precision( $args->{precision} );
        }
        else {
            $self->accuracy(undef);
        }

        delete $args->{accuracy};
        delete $args->{precision};

        foreach my $key (
            qw/
            round_mode div_scale
            upgrade downgrade
            trap_inf trap_nan
            /
          )
        {
            $self->$key( $args->{$key} ) if exists $args->{$key};
            delete $args->{$key};
        }

        if ( keys %$args ) {
            croak(
                "Illegal key(s) '",
                join( "', '", keys %$args ),
                "' passed to ${class}->config()"
            );
        }
    }

    my $cfg = {};

    if ( @_ == 1 && ( ref( $_[0] ) ne 'HASH' ) ) {
        my $param = shift;

        return $LIB              if $param eq 'lib';
        return $LIB->VERSION()   if $param eq 'lib_version';
        return $class            if $param eq 'class';
        return $class->VERSION() if $param eq 'version';

        return $self->$param();
    }

    else {

        if ( ref($self) ) {

            my @param = ( 'accuracy', 'precision' );

            for my $param (@param) {
                $cfg->{$param} = $self->{$param};
            }

        }
        else {

            my @param = (
                'accuracy', 'precision', 'round_mode', 'div_scale',
                'upgrade',  'downgrade', 'trap_inf',   'trap_nan'
            );

            for my $param (@param) {
                $cfg->{$param} = $self->$param();
            }

            $cfg->{lib}         = $LIB;
            $cfg->{lib_version} = $LIB->VERSION();
            $cfg->{class}       = $class;
            $cfg->{version}     = $class->VERSION();
        }

        return $cfg;
    }
}

sub _scale_a {
    my ( $x, $scale, $mode ) = @_;

    $scale = $x->{accuracy} unless defined $scale;

    my $class = ref($x);

    $mode = $class->round_mode() unless defined $mode;

    if ( defined $scale ) {
        $scale =
            $scale->can('numify')
          ? $scale->numify()
          : "$scale"
          if ref($scale);
        $scale = int($scale);
    }

    ( $scale, $mode );
}

sub _scale_p {
    my ( $x, $scale, $mode ) = @_;

    $scale = $x->{precision} unless defined $scale;

    my $class = ref($x);

    $scale = $class->precision()  unless defined $scale;
    $mode  = $class->round_mode() unless defined $mode;

    if ( defined $scale ) {
        $scale =
            $scale->can('numify')
          ? $scale->numify()
          : "$scale"
          if ref($scale);
        $scale = int($scale);
    }

    ( $scale, $mode );
}

sub _dng {
    my $self  = shift;
    my $class = ref($self);

    my $downgrade = $class->downgrade();
    return $self unless $downgrade;
    return $self if ref($self) eq $downgrade;

    my $upg = $downgrade->upgrade();
    my $dng = $downgrade->downgrade();

    $downgrade->upgrade(undef);
    $downgrade->downgrade(undef);

    my $tmp = $downgrade->new($self);

    $downgrade->upgrade($upg);
    $downgrade->downgrade($dng);

    for my $param ( 'accuracy', 'precision' ) {
        $tmp->{$param} = $self->{$param} if exists $self->{$param};
    }

    %$self = %$tmp;
    bless $self, $downgrade;

    return $self;
}

sub _upg {
    my $self  = shift;
    my $class = ref($self);

    my $upgrade = $class->upgrade();
    return $self unless $upgrade;
    return $self if ref($self) eq $upgrade;

    my $upg = $upgrade->upgrade();
    my $dng = $upgrade->downgrade();

    $upgrade->upgrade(undef);
    $upgrade->downgrade(undef);

    my $tmp = $upgrade->new($self);

    $upgrade->upgrade($upg);
    $upgrade->downgrade($dng);

    for my $param ( 'accuracy', 'precision' ) {
        $tmp->{$param} = $self->{$param} if exists $self->{$param};
    }

    %$self = %$tmp;
    bless $self, $upgrade;

    return $self;
}

sub _init {
    my $self  = shift;
    my $class = ref($self);

    $self->SUPER::_init() if SUPER->can('_init');

    $self->{accuracy}  = $class->accuracy();
    $self->{precision} = $class->precision();

    return $self;
}

sub new {

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $class->bzero() unless @_;

    my ( $wanted, @r ) = @_;

    if ( !defined($wanted) ) {
        return $class->bzero(@r);
    }

    if ( !ref($wanted) && $wanted eq "" ) {
        return $class->bnan(@r);
    }

    $self = bless {}, $class;

    if ( defined( blessed($wanted) ) && $wanted->isa(__PACKAGE__) ) {

        $self->{sign}  = $wanted->{sign};
        $self->{value} = $LIB->_copy( $wanted->{value} );
        $self->round(@r)
          unless @r >= 2 && !defined( $r[0] ) && !defined( $r[1] );
        return $self;
    }

    $wanted = "$wanted";

    if (
        $wanted =~ / ^

          # optional leading whitespace
          \s*

          # optional sign
          ( [+-]? )

          # integer mantissa with optional leading zeros
          0* ( [1-9] \d* (?: _ \d+ )* | 0 )

          # ... with optional zero fraction part
          (?: \.0* )?

          # optional non-negative exponent
          (?: [eE] \+? ( \d+ (?: _ \d+ )* ) )?

          # optional trailing whitespace
          \s*

          $
        /x
      )
    {
        my $sign = $1;
        ( my $mant = $2 ) =~ tr/_//d;
        my $expo = $3;
        $mant .= "0" x $expo if defined($expo) && $mant ne "0";

        $self->{sign}  = $sign eq "-" && $mant ne "0" ? "-" : "+";
        $self->{value} = $LIB->_new($mant);
        $self->round(@r);
        return $self;
    }

    if (
        $wanted =~ / ^
                     \s*
                     ( [+-]? )
                     inf (?: inity )?
                     \s*
                     \z
                   /ix
      )
    {
        my $sgn = $1 || '+';
        return $class->binf( $sgn, @r );
    }

    if (
        $wanted =~ / ^
                     \s*
                     ( [+-]? )
                     nan
                     \s*
                     \z
                   /ix
      )
    {
        return $class->bnan(@r);
    }

    my @parts;

    if (

        $wanted =~ /^\s*[+-]?0?[Xx]/
        and @parts = $class->_hex_str_to_flt_lib_parts($wanted)

        or

        $wanted =~ /^\s*[+-]?0?[Oo]/
        and @parts = $class->_oct_str_to_flt_lib_parts($wanted)

        or

        $wanted =~ /^\s*[+-]?0?[Bb]/
        and @parts = $class->_bin_str_to_flt_lib_parts($wanted)

        or

        @parts = $class->_dec_str_to_flt_lib_parts($wanted)
        or

        $wanted =~ /^\s*[+-]?0_*\d/
        and @parts = $class->_oct_str_to_flt_lib_parts($wanted)
      )
    {

        if ( $parts[2] eq '+' ) {
            $self->{sign}  = $parts[0];
            $self->{value} = $LIB->_lsft( $parts[1], $parts[3], 10 );
            $self->round(@r)
              unless @r >= 2 && !defined( $r[0] ) && !defined( $r[1] );
            return $self;
        }

        my $upg = $class->upgrade();
        return $upg->new( $wanted, @r ) if $upg;
    }

    return $class->bnan(@r);
}

sub from_dec {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_dec');

    my $str = shift;
    my @r   = @_;

    if ( my @parts = $class->_dec_str_to_flt_lib_parts($str) ) {

        unless ($selfref) {
            $self = bless {}, $class;
        }

        if ( $parts[2] eq '+' ) {
            $self->{sign}  = $parts[0];
            $self->{value} = $LIB->_lsft( $parts[1], $parts[3], 10 );
            return $self->round(@r);
        }

        my $upg = $class->upgrade();
        if ($upg) {
            return $self->_upg()->from_dec( $str, @r )
              if $selfref && $selfref ne $upg;
            return $upg->from_dec( $str, @r );
        }
    }

    return $self->bnan(@r);
}

sub from_hex {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_hex');

    my $str = shift;
    my @r   = @_;

    if ( my @parts = $class->_hex_str_to_flt_lib_parts($str) ) {

        unless ($selfref) {
            $self = bless {}, $class;
        }

        if ( $parts[2] eq '+' ) {
            $self->{sign}  = $parts[0];
            $self->{value} = $LIB->_lsft( $parts[1], $parts[3], 10 );
            return $self->round(@r);
        }

        my $upg = $class->upgrade();
        if ($upg) {
            return $self->_upg()->from_hex( $str, @r )
              if $selfref && $selfref ne $upg;
            return $upg->from_hex( $str, @r );
        }
    }

    return $self->bnan(@r);
}

sub from_oct {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_oct');

    my $str = shift;
    my @r   = @_;

    if ( my @parts = $class->_oct_str_to_flt_lib_parts($str) ) {

        unless ($selfref) {
            $self = bless {}, $class;
        }

        if ( $parts[2] eq '+' ) {
            $self->{sign}  = $parts[0];
            $self->{value} = $LIB->_lsft( $parts[1], $parts[3], 10 );
            return $self->round(@r);
        }

        my $upg = $class->upgrade();
        if ($upg) {
            return $self->_upg()->from_oct( $str, @r )
              if $selfref && $selfref ne $upg;
            return $upg->from_oct( $str, @r );
        }
    }

    return $self->bnan(@r);
}

sub from_bin {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_bin');

    my $str = shift;
    my @r   = @_;

    if ( my @parts = $class->_bin_str_to_flt_lib_parts($str) ) {

        unless ($selfref) {
            $self = bless {}, $class;
        }

        if ( $parts[2] eq '+' ) {
            $self->{sign}  = $parts[0];
            $self->{value} = $LIB->_lsft( $parts[1], $parts[3], 10 );
            return $self->round(@r);
        }

        my $upg = $class->upgrade();
        if ($upg) {
            return $self->_upg()->from_bin( $str, @r )
              if $selfref && $selfref ne $upg;
            return $upg->from_bin( $str, @r );
        }
    }

    return $self->bnan(@r);
}

sub from_bytes {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_bytes');

    croak("from_bytes() requires a newer version of the $LIB library.")
      unless $LIB->can('_from_bytes');

    my $str = shift;
    my @r   = @_;

    $self          = $class->bzero(@r) unless $selfref;
    $self->{sign}  = '+';
    $self->{value} = $LIB->_from_bytes($str);
    return $self->round(@r);
}

sub from_ieee754 {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_ieee754');

    my $in     = shift;
    my $format = shift;
    my @r      = @_;

    require Math::BigFloat;
    my $tmp = Math::BigFloat->from_ieee754( $in, $format, @r );
    return $self->bnan(@r) unless $tmp->is_inf() || $tmp->is_int();
    $tmp = $tmp->as_int();

    $self          = $class->bzero(@r) unless $selfref;
    $self->{sign}  = $tmp->{sign};
    $self->{value} = $tmp->{value};

    return $self;
}

sub from_base {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_base');

    my ( $str, $base, $cs, @r ) = @_;

    $base = $class->new($base) unless ref($base);

    croak("the base must be a finite integer >= 2")
      if $base < 2 || !$base->is_int();

    $self = $class->bzero() unless $selfref;

    unless ( defined $cs ) {
        return $self->from_bin( $str, @r ) if $base == 2;
        return $self->from_oct( $str, @r ) if $base == 8;
        return $self->from_hex( $str, @r ) if $base == 16;
        return $self->from_dec( $str, @r ) if $base == 10;
    }

    croak("from_base() requires a newer version of the $LIB library.")
      unless $LIB->can('_from_base');

    $self->{sign} = '+';
    $self->{value} =
      $LIB->_from_base( $str, $base->{value}, defined($cs) ? $cs : () );
    return $self->bround(@r);
}

sub from_base_num {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_base_num');

    my $nums = shift;
    $nums = [@$nums];

    for my $i ( 0 .. $#$nums ) {
        $nums->[$i] = $class->new( $nums->[$i] )
          unless defined( blessed( $nums->[$i] ) )
          && $nums->[$i]->isa(__PACKAGE__);
        croak "the elements must be finite non-negative integers"
          if $nums->[$i]->is_neg() || !$nums->[$i]->is_int();
    }

    my $base = shift;
    $base = $class->new($base)
      unless defined( blessed($base) ) && $base->isa(__PACKAGE__);

    my @r = @_;

    $self = $class->bzero(@r) unless $selfref;

    croak("from_base_num() requires a newer version of the $LIB library.")
      unless $LIB->can('_from_base_num');

    $self->{sign} = '+';
    $self->{value} =
      $LIB->_from_base_num( [ map { $_->{value} } @$nums ], $base->{value} );

    return $self->round(@r);
}

sub bzero {

    unless (
        @_
        && ( defined( blessed( $_[0] ) ) && $_[0]->isa(__PACKAGE__)
            || $_[0] =~ /^[a-z]\w*(?:::[a-z]\w*)*$/i )
      )
    {
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('bzero');

    my @r = @_;

    unless ($selfref) {
        $self = bless {}, $class;
    }

    $self->{sign}  = '+';
    $self->{value} = $LIB->_zero();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $_[0];
        $self->{precision} = $_[1];
    }
    elsif ( !$selfref ) {
        $self->{accuracy}  = $class->accuracy();
        $self->{precision} = $class->precision();
    }

    return $self;
}

sub bone {

    unless (
        @_
        && ( defined( blessed( $_[0] ) ) && $_[0]->isa(__PACKAGE__)
            || $_[0] =~ /^[a-z]\w*(?:::[a-z]\w*)*$/i )
      )
    {
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('bone');

    my ( $sign, @r ) = @_;

    if ( defined( $_[0] ) && $_[0] =~ /^\s*([+-])\s*$/ ) {
        $sign = $1;
        shift;
    }
    else {
        $sign = '+';
    }

    unless ($selfref) {
        $self = bless {}, $class;
    }

    $self->{sign}  = $sign;
    $self->{value} = $LIB->_one();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $_[0];
        $self->{precision} = $_[1];
    }
    elsif ( !$selfref ) {
        $self->{accuracy}  = $class->accuracy();
        $self->{precision} = $class->precision();
    }

    return $self;
}

sub binf {

    unless (
        @_
        && ( defined( blessed( $_[0] ) ) && $_[0]->isa(__PACKAGE__)
            || $_[0] =~ /^[a-z]\w*(?:::[a-z]\w*)*$/i )
      )
    {
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    {
        no strict 'refs';
        if ( ${"${class}::_trap_inf"} ) {
            croak("Tried to create +-inf in $class->binf()");
        }
    }

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('binf');

    my $sign = '+';
    if ( defined( $_[0] ) && $_[0] =~ /^\s*([+-])(inf|$)/i ) {
        $sign = $1;
        shift;
    }

    my @r = @_;

    unless ($selfref) {
        $self = bless {}, $class;
    }

    $self->{sign}  = $sign . 'inf';
    $self->{value} = $LIB->_zero();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $_[0];
        $self->{precision} = $_[1];
    }
    elsif ( !$selfref ) {
        $self->{accuracy}  = $class->accuracy();
        $self->{precision} = $class->precision();
    }

    return $self;
}

sub bnan {

    unless (
        @_
        && ( defined( blessed( $_[0] ) ) && $_[0]->isa(__PACKAGE__)
            || $_[0] =~ /^[a-z]\w*(?:::[a-z]\w*)*$/i )
      )
    {
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref($self);
    my $class   = $selfref || $self;

    {
        no strict 'refs';
        if ( ${"${class}::_trap_nan"} ) {
            croak("Tried to create NaN in $class->bnan()");
        }
    }

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('bnan');

    my @r = @_;

    unless ($selfref) {
        $self = bless {}, $class;
    }

    $self->{sign}  = $nan;
    $self->{value} = $LIB->_zero();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $_[0];
        $self->{precision} = $_[1];
    }
    elsif ( !$selfref ) {
        $self->{accuracy}  = $class->accuracy();
        $self->{precision} = $class->precision();
    }

    return $self;
}

sub bpi {

    unless (
        @_
        && ( defined( blessed( $_[0] ) ) && $_[0]->isa(__PACKAGE__)
            || $_[0] =~ /^[a-z]\w*(?:::[a-z]\w*)*$/i )
      )
    {
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;
    my @r       = @_;

    $class->import() if $IMPORT == 0;

    if ($selfref) {
        return $self if $self->modify('bpi');
    }
    else {
        $self = bless {}, $class;

    }

    my $upg = $class->upgrade();
    if ($upg) {
        return $self->_upg()->bpi(@r)
          if $selfref && $selfref ne $upg;
        return $upg->bpi(@r);
    }

    $self->{sign}  = '+';
    $self->{value} = $LIB->_new("3");
    $self->round(@r);
    return $self;
}

sub copy {
    my ( $x, $class );
    if ( ref( $_[0] ) ) {
        $x     = shift;
        $class = ref($x);
    }
    else {
        $class = shift;
        $x     = shift;
    }

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @_;

    my $copy = bless {}, $class;

    $copy->{sign}      = $x->{sign};
    $copy->{value}     = $LIB->_copy( $x->{value} );
    $copy->{accuracy}  = $x->{accuracy}  if exists $x->{accuracy};
    $copy->{precision} = $x->{precision} if exists $x->{precision};

    return $copy;
}

sub as_int {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    my $upg = Math::BigInt->upgrade();
    my $dng = Math::BigInt->downgrade();
    Math::BigInt->upgrade(undef);
    Math::BigInt->downgrade(undef);

    my $y;
    if ( $x->isa("Math::BigInt") ) {
        $y = $x->copy();
    }
    else {
        if ( $x->is_inf() ) {
            $y = Math::BigInt->binf( $x->sign() );
        }
        elsif ( $x->is_nan() ) {
            $y = Math::BigInt->bnan();
        }
        else {
            $y = Math::BigInt->new( $x->copy()->bint()->bdstr() );
        }

        ( $y->{accuracy}, $y->{precision} ) =
          ( $x->{accuracy}, $x->{precision} );
    }

    $y->round(@r);

    Math::BigInt->upgrade($upg);
    Math::BigInt->downgrade($dng);

    return $y;
}

sub as_rat {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    require Math::BigRat;
    my $upg = Math::BigRat->upgrade();
    my $dng = Math::BigRat->downgrade();
    Math::BigRat->upgrade(undef);
    Math::BigRat->downgrade(undef);

    my $y;
    if ( $x->isa("Math::BigRat") ) {
        $y = $x->copy();
    }
    else {

        if ( $x->is_inf() ) {
            $y = Math::BigRat->binf( $x->sign() );
        }
        elsif ( $x->is_nan() ) {
            $y = Math::BigRat->bnan();
        }
        else {
            $y = Math::BigRat->new( $x->bfstr() );
        }

        ( $y->{accuracy}, $y->{precision} ) =
          ( $x->{accuracy}, $x->{precision} );
    }

    $y->round(@r);

    Math::BigRat->upgrade($upg);
    Math::BigRat->downgrade($dng);

    return $y;
}

sub as_float {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    require Math::BigFloat;
    my $upg = Math::BigFloat->upgrade();
    my $dng = Math::BigFloat->downgrade();
    Math::BigFloat->upgrade(undef);
    Math::BigFloat->downgrade(undef);

    my $y;
    if ( $x->isa("Math::BigFloat") ) {
        $y = $x->copy();
    }
    else {
        if ( $x->is_inf() ) {
            $y = Math::BigFloat->binf( $x->sign() );
        }
        elsif ( $x->is_nan() ) {
            $y = Math::BigFloat->bnan();
        }
        else {
            if ( $x->isa("Math::BigRat") ) {
                if ( $x->is_int() ) {
                    $y = Math::BigFloat->new( $x->bdstr() );
                }
                else {
                    my ( $num, $den ) = $x->fparts();
                    my $str = $num->as_float()->bdiv( $den, @r )->bdstr();
                    $y = Math::BigFloat->new($str);
                }
            }
            else {
                $y = Math::BigFloat->new( $x->bdstr() );
            }
        }

        ( $y->{accuracy}, $y->{precision} ) =
          ( $x->{accuracy}, $x->{precision} );
    }

    $y->round(@r);

    Math::BigFloat->upgrade($upg);
    Math::BigFloat->downgrade($dng);

    return $y;
}

sub is_zero {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    return 0 if $x->{sign} ne '+';
    return 1 if $LIB->_is_zero( $x->{value} );
    return 0;
}

sub is_one {
    my ( undef, $x, $sign ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    if ( defined($sign) ) {
        croak 'is_one(): sign argument must be "+" or "-"'
          unless $sign eq '+' || $sign eq '-';
    }
    else {
        $sign = '+';
    }

    return 0 if $x->{sign} ne $sign;
    $LIB->_is_one( $x->{value} ) ? 1 : 0;
}

sub is_finite {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );
    $x->{sign} eq '+' || $x->{sign} eq '-' ? 1 : 0;
}

sub is_inf {
    my ( undef, $x, $sign ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    if ( defined $sign ) {
        $sign = '[+-]inf' if $sign eq '';
        $sign = "[$1]inf" if $sign =~ /^([+-])(inf)?$/;
        return $x->{sign} =~ /^$sign$/ ? 1 : 0;
    }
    $x->{sign} =~ /^[+-]inf$/ ? 1 : 0;
}

sub is_nan {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    $x->{sign} eq $nan ? 1 : 0;
}

sub is_positive {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    return 1 if $x->is_inf("+");

    ( $x->{sign} eq '+' && !$x->is_zero() ) ? 1 : 0;
}

sub is_negative {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    $x->{sign} =~ /^-/ ? 1 : 0;
}

sub is_non_positive {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    return 1 if $x->{sign} =~ /^\-/;
    return 1 if $x->is_zero();
    return 0;
}

sub is_non_negative {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    return 1 if $x->{sign} =~ /^\+/;
    return 1 if $x->is_zero();
    return 0;
}

sub is_odd {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    return 0 unless $x->is_finite();
    $LIB->_is_odd( $x->{value} ) ? 1 : 0;
}

sub is_even {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    return 0 unless $x->is_finite();
    $LIB->_is_even( $x->{value} ) ? 1 : 0;
}

sub is_int {
    my ( undef, $x ) = ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    $x->is_finite() ? 1 : 0;
}

sub bcmp {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    unless ( $x->is_finite() && $y->is_finite() ) {
        return    if $x->is_nan() || $y->is_nan();
        return 0  if $x->{sign} eq $y->{sign} && $x->{sign} =~ /^[+-]inf$/;
        return +1 if $x->is_inf("+");
        return -1 if $x->is_inf("-");
        return -1 if $y->is_inf("+");
        return +1;
    }

    return 1  if $x->{sign} eq '+' && $y->{sign} eq '-';
    return -1 if $x->{sign} eq '-' && $y->{sign} eq '+';

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bcmp( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    if ( $x->{sign} eq '+' ) {
        return $LIB->_acmp( $x->{value}, $y->{value} );
    }

    $LIB->_acmp( $y->{value}, $x->{value} );
}

sub bacmp {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( ( !$x->is_finite() ) || ( !$y->is_finite() ) ) {
        return   if $x->is_nan() || $y->is_nan();
        return 0 if $x->{sign} =~ /^[+-]inf$/ && $y->{sign} =~ /^[+-]inf$/;
        return 1 if $x->{sign} =~ /^[+-]inf$/ && $y->{sign} !~ /^[+-]inf$/;
        return -1;
    }

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bacmp( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $LIB->_acmp( $x->{value}, $y->{value} );
}

sub beq {
    my ( undef, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( undef, @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    my $cmp = $x->bcmp($y);
    return defined($cmp) && !$cmp;
}

sub bne {
    my ( undef, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( undef, @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    my $cmp = $x->bcmp($y);
    return defined($cmp) && !$cmp ? '' : 1;
}

sub blt {
    my ( undef, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( undef, @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    my $cmp = $x->bcmp($y);
    return defined($cmp) && $cmp < 0;
}

sub ble {
    my ( undef, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( undef, @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    my $cmp = $x->bcmp($y);
    return defined($cmp) && $cmp <= 0;
}

sub bgt {
    my ( undef, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( undef, @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    my $cmp = $x->bcmp($y);
    return defined($cmp) && $cmp > 0;
}

sub bge {
    my ( undef, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( undef, @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    my $cmp = $x->bcmp($y);
    return defined($cmp) && $cmp >= 0;
}

sub bneg {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bneg');

    $x->{sign} =~ tr/+-/-+/ unless $x->is_zero();
    $x->round(@r);
    $x->_dng() if ( $x->is_int() || $x->is_inf() || $x->is_nan() );
    return $x;
}

sub babs {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('babs');

    $x->{sign} =~ s/^-/+/;

    $x->round(@r);
    $x->_dng() if ( $x->is_int() || $x->is_inf() || $x->is_nan() );
    return $x;
}

sub bsgn {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bsgn');

    return $x->bone( "+", @r ) if $x->is_pos();
    return $x->bone( "-", @r ) if $x->is_neg();

    $x->round(@r);
    $x->_dng() if $x->is_int();
    return $x;
}

sub bnorm {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    $x;
}

sub binc {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('binc');

    return $x->round(@r) if $x->is_inf() || $x->is_nan();

    if ( $x->{sign} eq '+' ) {
        $x->{value} = $LIB->_inc( $x->{value} );
    }
    elsif ( $x->{sign} eq '-' ) {
        $x->{value} = $LIB->_dec( $x->{value} );
        $x->{sign}  = '+' if $LIB->_is_zero( $x->{value} );
    }

    return $x->round(@r);
}

sub bdec {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bdec');

    return $x->round(@r) if $x->is_inf() || $x->is_nan();

    if ( $x->{sign} eq '-' ) {
        $x->{value} = $LIB->_inc( $x->{value} );
    }
    elsif ( $x->{sign} eq '+' ) {
        if ( $LIB->_is_zero( $x->{value} ) ) {
            $x->{value} = $LIB->_one();
            $x->{sign}  = '-';
        }
        else {
            $x->{value} = $LIB->_dec( $x->{value} );
        }
    }

    return $x->round(@r);
}

sub badd {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x->badd( $y, @r ) unless $x->isa(__PACKAGE__);

    return $x if $x->modify('badd');

    $r[3] = $y;

    unless ( $x->is_finite() && $y->is_finite() ) {

        return $x->bnan(@r) if $x->is_nan() || $y->is_nan();

        return $x->is_inf("+")
          ? (
              $y->is_inf("-")
            ? $x->bnan(@r)
            : $x->binf( "+", @r )
          )
          : $x->is_inf("-") ? (
              $y->is_inf("+")
            ? $x->bnan(@r)
            : $x->binf( "-", @r )
          )
          : (
              $y->is_inf("+")
            ? $x->binf( "+", @r )
            : $x->binf( "-", @r )
          );
    }

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->badd( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    ( $x->{value}, $x->{sign} ) =
      $LIB->_sadd( $x->{value}, $x->{sign}, $y->{value}, $y->{sign} );

    $x->round(@r);
}

sub bsub {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x->bsub( $y, @r ) unless $x->isa(__PACKAGE__);

    return $x if $x->modify('bsub');

    $r[3] = $y;

    unless ( $x->is_finite() && $y->is_finite() ) {

        return $x->bnan(@r) if $x->is_nan() || $y->is_nan();

        return $x->is_inf("+")
          ? (
              $y->is_inf("+")
            ? $x->bnan(@r)
            : $x->binf( "+", @r )
          )
          : $x->is_inf("-") ? (
              $y->is_inf("-")
            ? $x->bnan(@r)
            : $x->binf( "-", @r )
          )
          : (
              $y->is_inf("+")
            ? $x->binf( "-", @r )
            : $x->binf( "+", @r )
          );
    }

    return $x->bzero(@r) if refaddr($x) eq refaddr($y);

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bsub( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    ( $x->{value}, $x->{sign} ) =
      $LIB->_ssub( $x->{value}, $x->{sign}, $y->{value}, $y->{sign} );

    $x->round(@r);
}

sub bmul {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bmul');

    return $x->bmul( $y, @r ) unless $x->isa(__PACKAGE__);

    return $x->bnan(@r) if $x->is_nan() || $y->is_nan();

    if ( ( $x->{sign} =~ /^[+-]inf$/ ) || ( $y->{sign} =~ /^[+-]inf$/ ) ) {
        return $x->bnan(@r) if $x->is_zero() || $y->is_zero();
        return $x->binf(@r) if ( $x->{sign} =~ /^\+/ && $y->{sign} =~ /^\+/ );
        return $x->binf(@r) if ( $x->{sign} =~ /^-/  && $y->{sign} =~ /^-/ );
        return $x->binf( '-', @r );
    }

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bmul( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $r[3] = $y;

    $x->{sign} = $x->{sign} eq $y->{sign} ? '+' : '-';

    $x->{value} = $LIB->_mul( $x->{value}, $y->{value} );
    $x->{sign}  = '+' if $LIB->_is_zero( $x->{value} );

    $x->round(@r);
}

*bdiv = \&bfdiv;
*bmod = \&bfmod;

sub bfdiv {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bfdiv');

    my $wantarray = wantarray;

    if ( $x->is_nan() || $y->is_nan() ) {
        return $wantarray
          ? ( $x->bnan(@r), $class->bnan(@r) )
          : $x->bnan(@r);
    }

    if ( $y->is_zero() ) {
        my $rem;
        if ($wantarray) {
            $rem = $x->copy()->round(@r);
        }
        if ( $x->is_zero() ) {
            $x->bnan(@r);
        }
        else {
            $x->binf( $x->{sign}, @r );
        }
        return $wantarray ? ( $x, $rem ) : $x;
    }

    if ( $x->is_inf() ) {
        my $rem;
        $rem = $class->bnan(@r) if $wantarray;
        if ( $y->is_inf() ) {
            $x->bnan(@r);
        }
        else {
            my $sign = $x->bcmp(0) == $y->bcmp(0) ? '+' : '-';
            $x->binf( $sign, @r );
        }
        return $wantarray ? ( $x, $rem ) : $x;
    }

    if ( $y->is_inf() ) {
        my $rem;
        if ( $x->is_zero() || $x->bcmp(0) == $y->bcmp(0) ) {
            $rem = $x->copy()->round(@r) if $wantarray;
            $x->bzero(@r);
        }
        else {
            $rem = $class->binf( $y->{sign}, @r ) if $wantarray;
            $x->bone( '-', @r );
        }
        return $wantarray ? ( $x, $rem ) : $x;
    }

    unless ($wantarray) {
        my $upg = $class->upgrade();
        if ($upg) {
            my $tmp = $upg->bfdiv( $x, $y, @r );
            if ( $tmp->is_int() ) {
                $tmp = $tmp->as_int();
                %$x  = %$tmp;
            }
            else {
                %$x = %$tmp;
                bless $x, $upg;
            }
            return $x;
        }
    }

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bfdiv( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $r[3] = $y;

    my $rem = $class->bzero();

    my $xsign = $x->{sign};
    my $ysign = $y->{sign};

    $y->{sign} =~ tr/+-/-+/;
    my $same = $xsign ne $x->{sign};
    $y->{sign} = $ysign;

    if ($same) {
        $x->bone();
    }
    else {

        ( $x->{value}, $rem->{value} ) =
          $LIB->_div( $x->{value}, $y->{value} );

        if ( $xsign ne $ysign && !$LIB->_is_zero( $rem->{value} ) ) {
            $x->{value} = $LIB->_inc( $x->{value} );
            $rem->{value} =
              $LIB->_sub( $LIB->_copy( $y->{value} ), $rem->{value} );
        }

        $x->{sign} =
          $xsign eq $ysign || $LIB->_is_zero( $x->{value} ) ? '+' : '-';
        $rem->{sign} =
          $ysign eq '+' || $LIB->_is_zero( $rem->{value} ) ? '+' : '-';
    }

    if ($wantarray) {
        $rem->{accuracy}  = $x->{accuracy};
        $rem->{precision} = $x->{precision};
        $x->round(@r);
        $rem->round(@r);
        return $x, $rem;
    }

    return $x->round(@r) if $LIB->_is_zero( $rem->{value} );

    $x->round(@r);
    return $x;
}

sub bfmod {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bfmod');

    $r[3] = $y;

    if ( $x->is_nan() || $y->is_nan() ) {
        return $x->bnan(@r);
    }

    if ( $y->is_zero() ) {
        return $x->round(@r);
    }

    if ( $x->is_inf() ) {
        return $x->bnan(@r);
    }

    if ( $y->is_inf() ) {
        if ( $x->is_zero() || $x->bcmp(0) == $y->bcmp(0) ) {
            return $x->round(@r);
        }
        else {
            return $x->binf( $y->sign(), @r );
        }
    }

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bfmod( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $x->{value} = $LIB->_mod( $x->{value}, $y->{value} );
    if ( $LIB->_is_zero( $x->{value} ) ) {
        $x->{sign} = '+';
    }
    else {
        $x->{value} = $LIB->_sub( $y->{value}, $x->{value}, 1 )
          if ( $x->{sign} ne $y->{sign} );
        $x->{sign} = $y->{sign};
    }

    $x->round(@r);
}

sub btdiv {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('btdiv');

    my $wantarray = wantarray;

    if ( $x->is_nan() || $y->is_nan() ) {
        return $wantarray
          ? ( $x->bnan(@r), $class->bnan(@r) )
          : $x->bnan(@r);
    }

    if ( $y->is_zero() ) {
        my $rem;
        if ($wantarray) {
            $rem = $x->copy(@r);
        }
        if ( $x->is_zero() ) {
            $x->bnan(@r);
        }
        else {
            $x->binf( $x->{sign}, @r );
        }
        return $wantarray ? ( $x, $rem ) : $x;
    }

    if ( $x->is_inf() ) {
        my $rem;
        $rem = $class->bnan(@r) if $wantarray;
        if ( $y->is_inf() ) {
            $x->bnan(@r);
        }
        else {
            my $sign = $x->bcmp(0) == $y->bcmp(0) ? '+' : '-';
            $x->binf( $sign, @r );
        }
        return $wantarray ? ( $x, $rem ) : $x;
    }

    if ( $y->is_inf() ) {
        my $rem;
        $rem = $x->copy()->round(@r) if $wantarray;
        $x->bzero(@r);
        return $wantarray ? ( $x, $rem ) : $x;
    }

    unless ($wantarray) {
        my $upg = $class->upgrade();
        if ($upg) {
            my $tmp = $upg->btdiv( $x, $y, @r );
            if ( $tmp->is_int() ) {
                $tmp = $tmp->as_int();
                %$x  = %$tmp;
            }
            else {
                %$x = %$tmp;
                bless $x, $upg;
            }
            return $x;
        }
    }

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->btdiv( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $r[3] = $y;

    my $rem = $class->bzero();

    my $xsign = $x->{sign};
    my $ysign = $y->{sign};

    $y->{sign} =~ tr/+-/-+/;
    my $same = $xsign ne $x->{sign};
    $y->{sign} = $ysign;

    if ($same) {
        $x->bone(@r);
    }
    else {
        ( $x->{value}, $rem->{value} ) =
          $LIB->_div( $x->{value}, $y->{value} );

        $x->{sign} = $xsign eq $ysign ? '+' : '-';
        $x->{sign} = '+' if $LIB->_is_zero( $x->{value} );
        $x->round(@r);
    }

    if ($wantarray) {
        $rem->{sign}      = $xsign;
        $rem->{sign}      = '+' if $LIB->_is_zero( $rem->{value} );
        $rem->{accuracy}  = $x->{accuracy};
        $rem->{precision} = $x->{precision};
        $rem->round(@r);
        return $x, $rem;
    }

    return $x;
}

sub btmod {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('btmod');

    $r[3] = $y;

    if ( $x->is_nan() || $y->is_nan() ) {
        return $x->bnan(@r);
    }

    if ( $y->is_zero() ) {
        return $x->round(@r);
    }

    if ( $x->is_inf() ) {
        return $x->bnan(@r);
    }

    if ( $y->is_inf() ) {
        return $x->round(@r);
    }

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->btmod( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    my $xsign = $x->{sign};

    $x->{value} = $LIB->_mod( $x->{value}, $y->{value} );

    $x->{sign} = $xsign;
    $x->{sign} = '+' if $LIB->_is_zero( $x->{value} );
    $x->round(@r);
}

sub binv {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    return $x if $x->modify('binv');

    return $x->binf( "+", @r ) if $x->is_zero();
    return $x->bzero(@r)       if $x->is_inf();
    return $x->bnan(@r)        if $x->is_nan();
    return $x->round(@r)       if $x->is_one("+") || $x->is_one("-");

    return $x->_upg()->binv(@r) if $class->upgrade();

    unless ( $x->isa(__PACKAGE__) ) {
        croak "Can't handle a ", ref($x), " in ", ( caller(0) )[3], "()";
    }

    $x->bzero(@r);
}

sub bsqrt {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bsqrt');

    return $x->round(@r)
      if ( $x->is_zero()
        || $x->is_one("+")
        || $x->is_nan()
        || $x->is_inf("+") );
    return $x->bnan(@r) if $x->is_negative();

    return $x->_upg()->bsqrt(@r) if $class->upgrade();

    unless ( $x->isa(__PACKAGE__) ) {
        croak "Can't handle a ", ref($x), " in ", ( caller(0) )[3], "()";
    }

    $x->{value} = $LIB->_sqrt( $x->{value} );
    return $x->round(@r);
}

sub bpow {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bpow');

    return $x->bnan(@r) if $x->is_nan() || $y->is_nan();

    if ( $x->is_inf("-") ) {
        return $x->bzero(@r) if $y->is_negative();
        return $x->bnan(@r)  if $y->is_zero();
        return $x->round(@r) if $y->is_odd();
        return $x->bneg(@r);
    }
    elsif ( $x->is_inf("+") ) {
        return $x->bzero(@r) if $y->is_negative();
        return $x->bnan(@r)  if $y->is_zero();
        return $x->round(@r);
    }
    elsif ( $y->is_inf("-") ) {
        return $x->bnan(@r)        if $x->is_one("-");
        return $x->binf( "+", @r ) if $x->is_zero();
        return $x->bone(@r)        if $x->is_one("+");
        return $x->bzero(@r);
    }
    elsif ( $y->is_inf("+") ) {
        return $x->bnan(@r)  if $x->is_one("-");
        return $x->bzero(@r) if $x->is_zero();
        return $x->bone(@r)  if $x->is_one("+");
        return $x->binf( "+", @r );
    }

    if ( $x->is_zero() ) {
        return $x->bone(@r) if $y->is_zero();
        return $x->binf(@r) if $y->is_negative();
        return $x->round(@r);
    }

    if ( $x->is_one("+") ) {
        return $x->round(@r);
    }

    if ( $x->is_one("-") ) {
        return $x->round(@r) if $y->is_odd();
        return $x->bneg(@r);
    }

    return $x->_upg()->bpow( $y, @r ) if $class->upgrade();

    if ( $y->{sign} eq '-' || !$y->isa(__PACKAGE__) ) {
        return $x->bzero(@r);
    }

    $r[3] = $y;

    $x->{value} = $LIB->_pow( $x->{value}, $y->{value} );
    $x->{sign}  = $x->is_negative() && $y->is_odd() ? '-' : '+';
    $x->round(@r);
}

sub broot {

    my ( $class, $x, $y, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    $y = $class->new("2") unless defined $y;

    return $x if $x->modify('broot');

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->broot( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    return $x->bnan(@r)
      if ( $x->{sign} !~ /^\+/
        || $y->is_zero()
        || $y->{sign} !~ /^\+$/ );

    return $x->round(@r)
      if $x->is_zero() || $x->is_one() || $x->is_inf() || $y->is_one();

    return $x->_upg()->broot( $y, @r ) if $class->upgrade();

    $x->{value} = $LIB->_root( $x->{value}, $y->{value} );
    $x->round(@r);
}

sub bmuladd {

    my ( $class, $x, $y, $z, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      && ref( $_[1] ) eq ref( $_[2] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 3, @_ );

    return $x if $x->modify('bmuladd');

    return $x->bnan(@r) if ( $x->is_nan()
        || $y->is_nan()
        || $z->is_nan() );

    if ( $x->is_inf("-") ) {

        if ( $y->is_neg() ) {
            if ( $z->is_inf("-") ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "+", @r );
            }
        }
        elsif ( $y->is_zero() ) {
            return $x->bnan(@r);
        }
        else {
            if ( $z->{sign} eq "+inf" ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "-", @r );
            }
        }

    }
    elsif ( $x->{sign} eq "+inf" ) {

        if ( $y->is_neg() ) {
            if ( $z->{sign} eq "+inf" ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "-", @r );
            }
        }
        elsif ( $y->is_zero() ) {
            return $x->bnan(@r);
        }
        else {
            if ( $z->is_inf("-") ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "+", @r );
            }
        }

    }
    elsif ( $x->is_neg() ) {

        if ( $y->is_inf("-") ) {
            if ( $z->is_inf("-") ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "+", @r );
            }
        }
        elsif ( $y->{sign} eq "+inf" ) {
            if ( $z->{sign} eq "+inf" ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "-", @r );
            }
        }
        else {
            if ( $z->is_inf("-") ) {
                return $x->binf( "-", @r );
            }
            elsif ( $z->{sign} eq "+inf" ) {
                return $x->binf( "+", @r );
            }
        }

    }
    elsif ( $x->is_zero() ) {

        if ( $y->is_inf("-") ) {
            return $x->bnan(@r);
        }
        elsif ( $y->{sign} eq "+inf" ) {
            return $x->bnan(@r);
        }
        else {
            if ( $z->is_inf("-") ) {
                return $x->binf( "-", @r );
            }
            elsif ( $z->{sign} eq "+inf" ) {
                return $x->binf( "+", @r );
            }
        }

    }
    elsif ( $x->is_pos() ) {

        if ( $y->is_inf("-") ) {
            if ( $z->{sign} eq "+inf" ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "-", @r );
            }
        }
        elsif ( $y->{sign} eq "+inf" ) {
            if ( $z->is_inf("-") ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "+", @r );
            }
        }
        else {
            if ( $z->is_inf("-") ) {
                return $x->binf( "-", @r );
            }
            elsif ( $z->{sign} eq "+inf" ) {
                return $x->binf( "+", @r );
            }
        }
    }

    unless ( $y->isa(__PACKAGE__) && $z->isa(__PACKAGE__) ) {
        if ( $y->is_int() && $z->is_int() ) {
            $y = $y->as_int();
            $z = $z->as_int();
        }
        else {
            return $x->_upg()->bmuladd( $y, $z, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()"
              unless $y->isa(__PACKAGE__);
            croak "Can't handle a ", ref($z), " in ", ( caller(0) )[3], "()"
              unless $z->isa(__PACKAGE__);
        }
    }

    $r[3] = $z;

    my $zs = $z->{sign};
    my $zv = $z->{value};
    $zv = $LIB->_copy($zv) if refaddr($x) eq refaddr($z);

    $x->{sign}  = $x->{sign} eq $y->{sign} ? '+' : '-';
    $x->{value} = $LIB->_mul( $x->{value}, $y->{value} );
    $x->{sign}  = '+' if $LIB->_is_zero( $x->{value} );

    ( $x->{value}, $x->{sign} ) =
      $LIB->_sadd( $x->{value}, $x->{sign}, $zv, $zs );
    return $x->round(@r);
}

sub bmodpow {
    my ( $class, $num, $exp, $mod, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      && ref( $_[1] ) eq ref( $_[2] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 3, @_ );

    return $num if $num->modify('bmodpow');

    return $num->bnan(@r)
      if ( !$num->is_finite()
        || !$exp->is_finite()
        || !$mod->is_finite() );

    unless ( $exp->isa(__PACKAGE__) && $mod->isa(__PACKAGE__) ) {
        if ( $exp->is_int() && $mod->is_int() ) {
            $exp = $exp->as_int();
            $mod = $mod->as_int();
        }
        else {
            return $num->_upg()->bmodpow( $exp, $mod, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($exp), " in ", ( caller(0) )[3], "()"
              unless $exp->isa(__PACKAGE__);
            croak "Can't handle a ", ref($mod), " in ", ( caller(0) )[3], "()"
              unless $mod->isa(__PACKAGE__);
        }
    }

    if ( $exp->{sign} eq '-' ) {
        $num->bmodinv($mod);
        return $num->bnan(@r) if $num->is_nan();
    }

    if ( $mod->is_zero() ) {
        if ( $num->is_zero() ) {
            return $num->bnan(@r);
        }
        else {
            return $num->round(@r);
        }
    }

    my $value = $LIB->_modpow( $num->{value}, $exp->{value}, $mod->{value} );
    my $sign  = '+';

    unless ( $LIB->_is_zero($value) ) {

        if ( $num->{sign} eq '-' && $exp->is_odd() ) {

            if ( $mod->{sign} eq '-' ) {
                $sign = '-';
            }

            else {
                my $mod = $LIB->_copy( $mod->{value} );
                $value = $LIB->_sub( $mod, $value );
                $sign  = '+';
            }

        }
        else {

            if ( $mod->{sign} eq '-' ) {
                my $mod = $LIB->_copy( $mod->{value} );
                $value = $LIB->_sub( $mod, $value );
                $sign  = '-';
            }

        }

    }

    $num->{value} = $value;
    $num->{sign}  = $sign;

    return $num->round(@r);
}

sub bmodinv {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bmodinv');

    return $x->bnan(@r) if !$y->is_finite() || !$x->is_finite();

    return $x->bnan(@r) if $y->is_zero();

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bmodinv( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    return $x->bzero(@r) if $y->is_one('+') || $y->is_one('-');

    $x->bfmod($y);
    return $x->bnan(@r) if $x->is_zero();

    ( $x->{value}, $x->{sign} ) = $LIB->_modinv( $x->{value}, $y->{value} );
    return $x->bnan(@r) if !defined( $x->{value} );

    $x->{sign} = '+' unless defined $x->{sign};

    $x->bneg() if $y->{sign} eq '-';

    $x->bmod($y) if $x->{sign} ne $y->{sign};

    $x->round(@r);
}

sub blog {

    my ( $class, $x, $base, @r );

    if ( !ref( $_[0] ) && $_[0] =~ /^[a-z]\w*(?:::\w+)*$/i ) {
        ( $class, $x, $base, @r ) =
          defined $_[2] ? objectify( 2, @_ ) : objectify( 1, @_ );
    }
    else {
        ( $class, $x, $base, @r ) =
          defined $_[1] ? objectify( 2, @_ ) : objectify( 1, @_ );
    }

    return $x if $x->modify('blog');

    return $x->bnan(@r) if $x->is_nan();

    if ( defined $base ) {
        $base = $class->new($base)
          unless defined( blessed($base) ) && $base->isa(__PACKAGE__);
        if ( $base->is_nan() || $base->is_one() ) {
            return $x->bnan(@r);
        }
        elsif ( $base->is_inf() || $base->is_zero() ) {
            return $x->bnan(@r) if $x->is_inf() || $x->is_zero();
            return $x->bzero(@r);
        }
        elsif ( $base->is_negative() ) {
            return $x->bzero(@r)       if $x->is_one();
            return $x->bone( '+', @r ) if $x == $base;

            return $x->_upg()->blog( $base, @r ) if $class->upgrade();
            return $x->bnan(@r);
        }
        return $x->bone(@r) if $x == $base;
    }

    if ( $x->is_inf() ) {
        return $x->binf( '+', @r );
    }
    elsif ( $x->is_neg() ) {
        return $x->_upg()->blog( $base, @r ) if $class->upgrade();
        return $x->bnan(@r);
    }
    elsif ( $x->is_one() ) {
        return $x->bzero(@r);
    }
    elsif ( $x->is_zero() ) {
        return $x->binf( '-', @r );
    }

    return $x->_upg()->blog( $base, @r ) if $class->upgrade();

    if ( !defined $base ) {
        require Math::BigFloat;

        my $upg = Math::BigFloat->upgrade();
        my $dng = Math::BigFloat->downgrade();
        Math::BigFloat->upgrade(undef);
        Math::BigFloat->downgrade(undef);

        my $u = Math::BigFloat->new($x)->blog()->as_int();

        Math::BigFloat->upgrade($upg);
        Math::BigFloat->downgrade($dng);

        $x->{value} = $u->{value};
        $x->{sign}  = $u->{sign};

        return $x->round(@r);
    }

    my ($rc) = $LIB->_log_int( $x->{value}, $base->{value} );
    return $x->bnan(@r) unless defined $rc;
    $x->{value} = $rc;
    $x->round(@r);
}

sub bexp {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bexp');

    return $x->bnan(@r)  if $x->is_nan();
    return $x->bone(@r)  if $x->is_zero();
    return $x->round(@r) if $x->is_inf("+");
    return $x->bzero(@r) if $x->is_inf("-");

    return $x->_upg()->bexp(@r) if $class->upgrade();

    unless ( $x->isa(__PACKAGE__) ) {
        croak "Can't handle a ", ref($x), " in ", ( caller(0) )[3], "()";
    }

    require Math::BigFloat;
    my $tmp = Math::BigFloat->bexp($x)->bint()->round(@r)->as_int();
    $x->{value} = $tmp->{value};
    return $x->round(@r);
}

sub bilog2 {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bilog2');

    return $x->bnan(@r) if $x->is_nan();
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->binf( "-", @r ) if $x->is_zero();

    if ( $x->is_neg() ) {
        return $x->_upg()->bilog2(@r) if $class->upgrade();
        return $x->bnan(@r);
    }

    $x->{value} = $LIB->_ilog2( $x->{value} );
    return $x->round(@r);
}

sub bilog10 {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bilog10');

    return $x->bnan(@r) if $x->is_nan();
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->binf( "-", @r ) if $x->is_zero();

    if ( $x->is_neg() ) {
        return $x->_upg()->bilog10(@r) if $class->upgrade();
        return $x->bnan(@r);
    }

    $x->{value} = $LIB->_ilog10( $x->{value} );
    return $x->round(@r);
}

sub bclog2 {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bclog2');

    return $x->bnan(@r) if $x->is_nan();
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->binf( "-", @r ) if $x->is_zero();

    if ( $x->is_neg() ) {
        return $x->_upg()->bclog2(@r) if $class->upgrade();
        return $x->bnan(@r);
    }

    $x->{value} = $LIB->_clog2( $x->{value} );
    return $x->round(@r);
}

sub bclog10 {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bclog10');

    return $x->bnan(@r) if $x->is_nan();
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->binf( "-", @r ) if $x->is_zero();

    if ( $x->is_neg() ) {
        return $x->_upg()->bclog10(@r) if $class->upgrade();
        return $x->bnan(@r);
    }

    $x->{value} = $LIB->_clog10( $x->{value} );
    return $x->round(@r);
}

sub bnok {

    my ( $class, $n, $k, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $n if $n->modify('bnok');

    unless ( $k->isa(__PACKAGE__) ) {
        if ( $k->is_int() ) {
            $k = $k->as_int();
        }
        else {
            return $n->_upg()->bnok( $k, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($k), " in ", ( caller(0) )[3], "()";
        }
    }

    return $n->bnan(@r) if $n->is_nan() || $k->is_nan();

    if ( $n->is_inf() ) {
        if ( $k->is_inf() ) {
            return $n->bnan(@r);
        }
        elsif ( $k->is_neg() ) {
            return $n->bzero(@r);
        }
        elsif ( $k->is_zero() ) {
            return $n->bone(@r);
        }
        else {
            if ( $n->is_inf( "+", @r ) ) {
                return $n->binf("+");
            }
            else {
                my $sign = $k->is_even() ? "+" : "-";
                return $n->binf( $sign, @r );
            }
        }
    }

    elsif ( $k->is_inf() ) {
        return $n->bnan(@r);
    }

    my $sign = 1;

    if ( $n >= 0 ) {
        if ( $k < 0 || $k > $n ) {
            return $n->bzero(@r);
        }
    }
    else {

        if ( $k >= 0 ) {

            $sign = (-1)**$k;
            $n->bneg()->badd($k)->bdec();

        }
        elsif ( $k <= $n ) {

            $sign = (-1)**( $n - $k );
            my $x0 = $n->copy();
            $n->bone()->badd($k)->bneg();
            $k = $k->copy();
            $k->bneg()->badd($x0);

        }
        else {

            return $n->bzero(@r);
        }
    }

    my $k_val = $k->{value};
    my $two_k = $LIB->_mul( $LIB->_two(), $k_val );
    if ( $LIB->_acmp( $two_k, $n->{value} ) > 0 ) {
        $k_val = $LIB->_sub( $LIB->_copy( $n->{value} ), $k_val );
    }

    $n->{value} = $LIB->_nok( $n->{value}, $k_val );
    $n->bneg() if $sign == -1;
    $n->round(@r);
}

sub bperm {

    my ( $class, $n, $k, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $n if $n->modify('bnok');

    unless ( $k->isa(__PACKAGE__) ) {
        if ( $k->is_int() ) {
            $k = $k->as_int();
        }
        else {
            return $n->_upg()->bperm( $k, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($k), " in ", ( caller(0) )[3], "()";
        }
    }

    return $n->bnan(@r) if $n->is_nan() || $k->is_nan();
    return $n->bnan(@r) unless $n >= $k && $k >= 0;
    return $n->bone( "+", @r ) if $k->is_zero();

    if ( $n->is_inf() ) {
        if ( $k->is_inf() ) {
            return $n->bnan(@r);
        }
        else {
            return $n->binf( "+", @r );
        }
    }

    my $factor = $LIB->_copy( $n->{value} );

    my $limit = $LIB->_copy( $n->{value} );
    $limit = $LIB->_sub( $limit, $k->{value} );
    $limit = $LIB->_inc($limit);

    while ( $LIB->_acmp( $factor, $limit ) > 0 ) {
        $LIB->_dec($factor);
        $LIB->_mul( $n->{value}, $factor );
    }

    $n->round(@r);
}

sub bhyperop {
    my ( $class, $a, $n, $b, @r ) = objectify( 3, @_ );

    return $a if $a->modify('bhyperop');

    my $tmp = $a->hyperop( $n, $b );
    $a->{value} = $tmp->{value};
    return $a->round(@r);
}

sub hyperop {
    my ( $class, $a, $n, $b, @r ) = objectify( 3, @_ );

    croak("a must be non-negative") if $a < 0;
    croak("n must be non-negative") if $n < 0;
    croak("b must be non-negative") if $b < 0;

    my @stack = ( $a, $n, $b );
    while ( @stack > 1 ) {
        my ( $a, $n, $b ) = splice @stack, -3;

        if ( $b == 2 && $a == 2 ) {
            push @stack, $n == 0
              ? Math::BigInt->new("3")
              : Math::BigInt->new("4");
            next;
        }

        if ( $b == 1 ) {
            if ( $n == 0 ) {
                push @stack, Math::BigInt->new("2");
                next;
            }
            if ( $n == 1 ) {
                push @stack, $a + 1;
                next;
            }
            push @stack, $a;
            next;
        }

        if ( $b == 0 ) {
            if ( $n == 1 ) {
                push @stack, $a;
                next;
            }
            if ( $n == 2 ) {
                push @stack, Math::BigInt->bzero();
                next;
            }
            push @stack, Math::BigInt->bone();
            next;
        }

        if ( $a == 0 ) {
            if ( $n == 0 ) {
                push @stack, $b + 1;
                next;
            }
            if ( $n == 1 ) {
                push @stack, $b;
                next;
            }
            if ( $n == 2 ) {
                push @stack, Math::BigInt->bzero();
                next;
            }
            if ( $n == 3 ) {
                push @stack, $b == 0
                  ? Math::BigInt->bone()
                  : Math::BigInt->bzero();
                next;
            }
            push @stack, $b->is_odd()
              ? Math::BigInt->bzero()
              : Math::BigInt->bone();
            next;
        }

        if ( $a == 1 ) {
            if ( $n == 0 || $n == 1 ) {
                push @stack, $b + 1;
                next;
            }
            if ( $n == 2 ) {
                push @stack, $b;
                next;
            }
            push @stack, Math::BigInt->bone();
            next;
        }

        if ( $n == 4 ) {
            if ( $b == 0 ) {
                push @stack, Math::BigInt->bone();
                next;
            }
            my $y = $a;
            $y = $a**$y for 2 .. $b;
            push @stack, $y;
            next;
        }

        if ( $n == 3 ) {
            push @stack, $a**$b;
            next;
        }

        if ( $n == 2 ) {
            push @stack, $a * $b;
            next;
        }

        if ( $n == 1 ) {
            push @stack, $a + $b;
            next;
        }

        if ( $n == 0 ) {
            push @stack, $b + 1;
            next;
        }

        push @stack, $a, $n - 1, $a, $n, $b - 1;
    }

    $a = pop @stack;
    return $a->round(@r);
}

sub buparrow {
    my ( $class, $a, $n, $b, @r ) = objectify( 3, @_ );

    return $a if $a->modify('buparrow');

    $a->bhyperop( $n + 2, $b, @r );
}

sub uparrow {
    my ( $class, $a, $n, $b, @r ) = objectify( 3, @_ );
    $a->hyperop( $n + 2, $b, @r );
}

sub backermann {
    my $m = shift;

    return $m if $m->modify('backermann');

    my $y = $m->ackermann(@_);
    $m->{value} = $y->{value};
    return $m;
}

sub ackermann {

    my ( $m, $n ) = @_;
    my $class = ref $m;
    croak("m must be non-negative") if $m < 0;
    croak("n must be non-negative") if $n < 0;

    my $two      = $class->new("2");
    my $three    = $class->new("3");
    my $thirteen = $class->new("13");

    $n = pop;
    $n = $class->new($n) unless ref($n);
    while (@_) {
        my $m = pop;
        if ( $m > $three ) {
            push @_, ( --$m ) x $n;
            while ( --$m >= $three ) {
                push @_, $m;
            }
            $n = $thirteen;
        }
        elsif ( $m == $three ) {
            $n = $class->bone()->blsft( $n + $three )->bsub($three);
        }
        elsif ( $m == $two ) {
            $n->bmul($two)->badd($three);
        }
        elsif ( $m >= 0 ) {
            $n->badd($m)->binc();
        }
        else {
            die "negative m!";
        }
    }
    $n;
}

sub bsin {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bsin');

    return $x->bzero(@r) if $x->is_zero();
    return $x->bnan(@r)  if $x->is_inf() || $x->is_nan();

    my $upg = $class->upgrade();
    if ($upg) {
        my $xtmp = $upg->bsin( $x, @r );
        if ( $xtmp->is_int() ) {
            $xtmp = $xtmp->as_int();
            %$x   = %$xtmp;
        }
        else {
            %$x = %$xtmp;
            bless $x, $upg;
        }
        return $x;
    }

    $x->bzero(@r);
}

sub bcos {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bcos');

    return $x->bone(@r) if $x->is_zero();
    return $x->bnan(@r) if $x->is_inf() || $x->is_nan();

    my $upg = $class->upgrade();
    if ($upg) {
        my $xtmp = $upg->bcos( $x, @r );
        if ( $xtmp->is_int() ) {
            $xtmp = $xtmp->as_int();
            %$x   = %$xtmp;
        }
        else {
            %$x = %$xtmp;
            bless $x, $upg;
        }
        return $x;
    }

    $x->bzero(@r);
}

sub batan {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('batan');

    return $x->bnan(@r)  if $x->is_nan();
    return $x->bzero(@r) if $x->is_zero();

    return $x->_upg()->batan(@r) if $class->upgrade();

    return $x->bone( "+", @r ) if $x->bgt("1");
    return $x->bone( "-", @r ) if $x->blt("-1");

    $x->bzero(@r);
}

sub batan2 {

    my ( $class, $y, $x, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $y if $y->modify('batan2');

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $y->_upg()->batan2( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    return $y->bnan() if $y->is_nan() || $x->is_nan();

    if ( $x->is_inf() || $y->is_inf() ) {
        if ( $y->is_inf() ) {
            if ( $x->is_inf("-") ) {
                $y->bone( substr( $y->{sign}, 0, 1 ) );
                $y->bmul( $class->new(2) );
            }
            elsif ( $x->is_inf("+") ) {
                $y->bzero();
            }
            else {
                $y->bone( substr( $y->{sign}, 0, 1 ) );
            }
        }
        else {
            if ( $x->is_inf("+") ) {
                $y->bzero();
            }
            else {
                $y->bone( substr( $y->{sign}, 0, 1 ) );
                $y->bmul( $class->new(3) );
            }
        }
        return $y;
    }

    my $dng = Math::BigFloat->downgrade();
    Math::BigFloat->downgrade(undef);

    my $yflt = $y->as_float();
    my $xflt = $x->as_float();
    my $yint = $yflt->batan2( $xflt, @r )->as_int();

    $y->{value} = $yint->{value};
    $y->{sign}  = $yint->{sign};

    Math::BigFloat->downgrade($dng);
    $y->round(@r);
}

sub bfac {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bfac');

    return $x->bnan(@r)        if $x->is_nan() || $x->is_inf("-");
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->bnan(@r)        if $x->is_neg();
    return $x->bone(@r)        if $x->is_zero() || $x->is_one();

    $x->{value} = $LIB->_fac( $x->{value} );
    $x->round(@r);
}

sub bdfac {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bdfac');

    return $x->bnan(@r)        if $x->is_nan() || $x->is_inf("-");
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->bnan(@r)        if $x <= -2;
    return $x->bone(@r)        if $x <= 1;

    croak("bdfac() requires a newer version of the $LIB library.")
      unless $LIB->can('_dfac');

    $x->{value} = $LIB->_dfac( $x->{value} );
    $x->round(@r);
}

sub btfac {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('btfac');

    return $x->bnan(@r)        if $x->is_nan();
    return $x->binf( "+", @r ) if $x->is_inf("+");

    my $k = $class->new("3");
    return $x->bnan(@r) if $x <= -$k;

    my $one = $class->bone();
    return $x->bone(@r) if $x <= $one;

    my $f = $x->copy();
    while ( $f->bsub($k) > $one ) {
        $x->bmul($f);
    }
    $x->round(@r);
}

sub bmfac {

    my ( $class, $x, $k, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bmfac');

    return $x->bnan(@r)        if $x->is_nan();
    return $x->bnan(@r)        if $k->is_nan();
    return $x->binf( "+", @r ) if $x->is_inf("+");

    unless ( $k->isa(__PACKAGE__) ) {
        if ( $k->is_int() ) {
            $k = $k->as_int();
        }
        else {
            return $x->_upg()->bmfac( $k, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($k), " in ", ( caller(0) )[3], "()";
        }
    }

    return $x->bnan(@r) if $k < 1 || $x <= -$k;

    my $one = $class->bone();
    return $x->bone(@r) if $x <= $one;

    my $f = $x->copy();
    while ( $f->bsub($k) > $one ) {
        $x->bmul($f);
    }
    $x->round(@r);
}

sub bfib {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    croak("bfib() requires a newer version of the $LIB library.")
      unless $LIB->can('_fib');

    return $x if $x->modify('bfib');

    if (wantarray) {
        croak("bfib() can't return an infinitely long list of numbers")
          if $x->is_inf();

        return if $x->is_nan() || !$x->is_int();

        my $n = $x->numify();

        my @y;
        {
            $y[0] = $x->copy()->babs();
            $y[0]{value} = $LIB->_zero();
            last if $n == 0;

            $y[1] = $y[0]->copy();
            $y[1]{value} = $LIB->_one();
            last if $n == 1;

            for ( my $i = 2 ; $i <= abs($n) ; $i++ ) {
                $y[$i] = $y[ $i - 1 ]->copy();
                $y[$i]{value} = $LIB->_add( $LIB->_copy( $y[ $i - 1 ]{value} ),
                    $y[ $i - 2 ]{value} );
            }

            if ( $x->is_neg() ) {
                for ( my $i = 2 ; $i <= $#y ; $i += 2 ) {
                    $y[$i]{sign} = '-';
                }
            }

            $x->{value} = $y[-1]{value};
            $x->{sign}  = $y[-1]{sign};
            $y[-1]      = $x;
        }

        @y = map { $_->round(@r) } @y;
        return @y;
    }

    else {
        return $x         if $x->is_inf('+');
        return $x->bnan() if $x->is_nan() || $x->is_inf('-');

        $x->{sign}  = $x->is_neg() && $x->is_even() ? '-' : '+';
        $x->{value} = $LIB->_fib( $x->{value} );
        return $x->round(@r);
    }
}

sub blucas {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    croak("blucas() requires a newer version of the $LIB library.")
      unless $LIB->can('_lucas');

    return $x if $x->modify('blucas');

    if (wantarray) {
        return if $x->is_nan();
        croak("blucas() can't return an infinitely long list of numbers")
          if $x->is_inf();

        my $n = $x->numify();

        my @y;
        {
            $y[0] = $x->copy()->babs();
            $y[0]{value} = $LIB->_two();
            last if $n == 0;

            $y[1] = $y[0]->copy();
            $y[1]{value} = $LIB->_one();
            last if $n == 1;

            for ( my $i = 2 ; $i <= abs($n) ; $i++ ) {
                $y[$i] = $y[ $i - 1 ]->copy();
                $y[$i]{value} = $LIB->_add( $LIB->_copy( $y[ $i - 1 ]{value} ),
                    $y[ $i - 2 ]{value} );
            }

            if ( $x->is_neg() ) {
                for ( my $i = 2 ; $i <= $#y ; $i += 2 ) {
                    $y[$i]{sign} = '-';
                }
            }

            $x->{value} = $y[-1]{value};
            $x->{sign}  = $y[-1]{sign};
            $y[-1]      = $x;
        }

        @y = map { $_->round(@r) } @y;
        return @y;
    }

    else {
        return $x         if $x->is_inf('+');
        return $x->bnan() if $x->is_nan() || $x->is_inf('-');

        $x->{sign}  = $x->is_neg() && $x->is_even() ? '-' : '+';
        $x->{value} = $LIB->_lucas( $x->{value} );
        return $x->round(@r);
    }
}

sub blsft {

    my ( $class, $x, $y, $b, @r );

    if ( !ref( $_[0] ) && $_[0] =~ /^[A-Za-z]|::/ ) {
        ( $class, $x, $y, $b, @r ) =
          defined $_[3] ? objectify( 3, @_ ) : objectify( 2, @_ );
    }
    else {
        ( $class, $x, $y, $b, @r ) =
          defined $_[2] ? objectify( 3, @_ ) : objectify( 2, @_ );
    }

    return $x if $x->modify('blsft');

    $b = 2               unless defined $b;
    $b = $class->new($b) unless defined( blessed($b) );

    unless ( $y->isa(__PACKAGE__) && $b->isa(__PACKAGE__) ) {
        if ( $y->is_int() && $b->is_int() ) {
            $y = $y->as_int();
            $b = $b->as_int();
        }
        else {
            return $x->_upg()->blsft( $y, $b, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($x), " in ", ( caller(0) )[3], "()"
              unless $y->isa(__PACKAGE__);
            croak "Can't handle a ", ref($b), " in ", ( caller(0) )[3], "()"
              unless $b->isa(__PACKAGE__);
        }
    }

    return $x->bnan(@r)
      if $x->is_nan() || $y->is_nan() || $b->is_nan();

    return $x->brsft( $y->copy()->bneg(), $b, @r ) if $y->is_neg();

    if ( $y->is_inf("+") ) {
        if ( $b->is_one("-") ) {
            return $x->bnan(@r);
        }
        elsif ( $b->is_one("+") ) {
            return $x->round(@r);
        }
        elsif ( $b->is_zero() ) {
            return $x->bnan(@r) if $x->is_inf();
            return $x->bzero(@r);
        }
        else {
            return $x->binf( "-", @r ) if $x->is_negative();
            return $x->binf( "+", @r ) if $x->is_positive();
            return $x->bnan(@r);
        }
    }

    if ( $b->is_inf() ) {
        return $x->bnan(@r) if $x->is_zero() || $y->is_zero();
        if ( $b->is_inf("-") ) {
            return $x->binf( "+", @r )
              if ( $x->is_negative() && $y->is_odd()
                || $x->is_positive() && $y->is_even() );
            return $x->binf( "-", @r );
        }
        else {
            return $x->binf( "-", @r ) if $x->is_negative();
            return $x->binf( "+", @r );
        }
    }

    if ( $b->is_zero() ) {
        return $x->round(@r) if $y->is_zero();
        return $x->bnan(@r)  if $x->is_inf();
        return $x->bzero(@r);
    }

    if ( $x->is_inf() ) {
        if ( $b->is_negative() ) {
            if ( $x->is_inf("-") ) {
                if ( $y->is_even() ) {
                    return $x->round(@r);
                }
                else {
                    return $x->binf( "+", @r );
                }
            }
            else {
                if ( $y->is_even() ) {
                    return $x->round(@r);
                }
                else {
                    return $x->binf( "-", @r );
                }
            }
        }
        else {
            return $x->round(@r);
        }
    }

    return $x->round(@r)
      if $x->is_zero()
      || $y->is_zero()
      || $b->is_one("+")
      || $b->is_one("-") && $y->is_even();

    return $x->bneg(@r) if $b->is_one("-") && $y->is_odd();

    my $uintmax = ~0;
    if ( $x->bcmp($uintmax) > 0 ) {
        $x->bmul( $b->bpow($y) );
    }
    else {
        my $neg = 0;
        if ( $b->is_negative() ) {
            $neg = 1 if $y->is_odd();
            $b->babs();
        }
        $b = $b->numify();
        $x->{value} = $LIB->_lsft( $x->{value}, $y->{value}, $b );
        $x->{sign} =~ tr/+-/-+/ if $neg;
    }
    $x->round(@r);
}

sub brsft {

    my ( $class, $x, $y, $b, @r );

    if ( !ref( $_[0] ) && $_[0] =~ /^[A-Za-z]|::/ ) {
        ( $class, $x, $y, $b, @r ) =
          defined $_[3] ? objectify( 3, @_ ) : objectify( 2, @_ );
    }
    else {
        ( $class, $x, $y, $b, @r ) =
          defined $_[2] ? objectify( 3, @_ ) : objectify( 2, @_ );
    }

    return $x if $x->modify('brsft');

    $b = 2               unless defined $b;
    $b = $class->new($b) unless defined( blessed($b) );

    unless ( $y->isa(__PACKAGE__) && $b->isa(__PACKAGE__) ) {
        if ( $y->is_int() && $b->is_int() ) {
            $y = $y->as_int();
            $b = $b->as_int();
        }
        else {
            return $x->_upg()->brsft( $y, $b, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($x), " in ", ( caller(0) )[3], "()"
              unless $y->isa(__PACKAGE__);
            croak "Can't handle a ", ref($b), " in ", ( caller(0) )[3], "()"
              unless $b->isa(__PACKAGE__);
        }
    }

    return $x->bnan(@r)
      if $x->is_nan() || $y->is_nan() || $b->is_nan();

    return $x->blsft( $y->copy()->bneg(), $b, @r ) if $y->is_neg();

    if ( $b->is_inf() ) {
        return $x->bnan(@r) if $x->is_inf() || $y->is_zero();
        if ( $b->is_inf("+") ) {
            if ( $x->is_negative() ) {
                return $x->bone( "-", @r );
            }
            else {
                return $x->bzero(@r);
            }
        }
        else {
            if ( $x->is_negative() ) {
                return $y->is_odd()
                  ? $x->bzero(@r)
                  : $x->bone( "-", @r );
            }
            elsif ( $x->is_positive() ) {
                return $y->is_odd()
                  ? $x->bone( "-", @r )
                  : $x->bzero(@r);
            }
            else {
                return $x->bzero(@r);
            }
        }
    }

    if ( $b->is_zero() ) {
        return $x->round(@r) if $y->is_zero();
        return $x->bnan(@r)  if $x->is_zero();
        return $x->is_negative()
          ? $x->binf( "-", @r )
          : $x->binf( "+", @r );
    }

    if ( $y->is_inf("+") ) {
        if ( $b->is_one("-") ) {
            return $x->bnan(@r);
        }
        elsif ( $b->is_one("+") ) {
            return $x->round(@r);
        }
        else {
            return $x->bnan(@r) if $x->is_inf();
            return $x->is_negative()
              ? $x->bone( "-", @r )
              : $x->bzero(@r);
        }
    }

    if ( $x->is_inf() ) {
        if ( $b->is_negative() ) {
            if ( $x->is_inf("-") ) {
                if ( $y->is_even() ) {
                    return $x->round(@r);
                }
                else {
                    return $x->binf( "+", @r );
                }
            }
            else {
                if ( $y->is_even() ) {
                    return $x->round(@r);
                }
                else {
                    return $x->binf( "-", @r );
                }
            }
        }
        else {
            return $x->round(@r);
        }
    }

    return $x->round(@r)
      if $x->is_zero()
      || $y->is_zero()
      || $b->is_one("+")
      || $b->is_one("-") && $y->is_even();

    return $x->bneg(@r) if $b->is_one("-") && $y->is_odd();

    return $x->_upg()->brsft( $y, $b, @r ) if $class->upgrade();

    if ( $x->is_neg() && $b->bcmp("2") == 0 ) {
        return $x->round(@r) if $x->is_one('-');

        $x->binc();
        my $bin = $x->to_bin();
        $bin =~ s/^-//;
        $bin =~ tr/10/01/;
        my $nbits = CORE::length($bin);
        return $x->bone( "-", @r ) if $y >= $nbits;
        $bin = substr $bin, 0, $nbits - $y;
        $bin = '1' . $bin;
        $bin =~ tr/10/01/;
        my $res = $class->from_bin($bin);
        $res->binc();
        $x->{value} = $res->{value};
        return $x->round(@r);
    }

    my $uintmax = ~0;
    if ( $x->bcmp($uintmax) > 0 || $x->is_neg() || $b->is_negative() ) {
        $x->bdiv( $b->bpow($y) );
    }
    else {
        $b = $b->numify();
        $x->{value} = $LIB->_rsft( $x->{value}, $y->{value}, $b );
    }

    return $x->round(@r);
}

sub bblsft {

    my ( $class, $x, $y, @r );

    if ( ref( $_[0] ) ) {
        ( $class, $x, $y, @r ) = ( ref( $_[0] ), @_ );
        $y = $y->as_int()
          if ref($y) && !$y->isa(__PACKAGE__) && $y->can('as_int');
        $y = $class->new( int($y) ) unless ref($y);
    }

    else {
        ( $class, $x, $y, @r ) = @_;
        for ( $x, $y ) {
            $_ = $_->as_int()
              if ref($_) && !$_->isa(__PACKAGE__) && $_->can('as_int');
            $_ = $class->new( int($_) ) unless ref($_);
        }
    }

    return $x if $x->modify('bblsft');

    return $x->bnan(@r) if $x->is_nan() || $y->is_nan();

    return $x->bbrsft( $y->copy()->bneg() ) if $y->is_neg();

    if ( $y->is_inf("+") ) {
        return $x->binf( "+", @r ) if $x->is_pos();
        return $x->binf( "-", @r ) if $x->is_neg();
        return $x->bnan(@r);
    }

    return $x->round(@r)
      if $x->is_zero()
      || $x->is_inf()
      || $y->is_zero();

    $x->{value} = $LIB->_lsft( $x->{value}, $y->{value}, 2 );
    $x->round(@r);
}

sub bbrsft {

    my ( $class, $x, $y, @r );

    if ( ref( $_[0] ) ) {
        ( $class, $x, $y, @r ) = ( ref( $_[0] ), @_ );
        $y = $y->as_int()
          if ref($y) && !$y->isa(__PACKAGE__) && $y->can('as_int');
        $y = $class->new( int($y) ) unless ref($y);
    }

    else {
        ( $class, $x, $y, @r ) = @_;
        for ( $x, $y ) {
            $_ = $_->as_int()
              if ref($_) && !$_->isa(__PACKAGE__) && $_->can('as_int');
            $_ = $class->new( int($_) ) unless ref($_);
        }
    }

    return $x if $x->modify('bbrsft');

    return $x->bnan(@r) if $x->is_nan() || $y->is_nan();

    return $x->bblsft( $y->copy()->bneg() ) if $y->is_neg();

    if ( $y->is_inf("+") ) {
        return $x->bnan(@r)        if $x->is_inf();
        return $x->bone( "-", @r ) if $x->is_neg();
        return $x->bzero(@r);
    }

    return $x->round(@r)
      if $x->is_zero()
      || $x->is_inf()
      || $y->is_zero();

    if ( $x->is_pos() ) {
        $x->{value} = $LIB->_rsft( $x->{value}, $y->{value}, 2 );
    }
    else {
        my $n = $x->{value};
        my $d = $LIB->_pow( $LIB->_new("2"), $y->{value} );
        my ( $p, $q ) = $LIB->_div( $n, $d );
        $p = $LIB->_inc($p) unless $LIB->_is_zero($q);
        $x->{value} = $p;
    }

    $x->round(@r);
}

sub band {

    my ( $class, $x, $y, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('band');

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->band( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $r[3] = $y;

    return $x->bnan(@r) if !$x->is_finite() || !$y->is_finite();

    if ( $x->{sign} eq '+' && $y->{sign} eq '+' ) {
        $x->{value} = $LIB->_and( $x->{value}, $y->{value} );
    }
    else {
        ( $x->{value}, $x->{sign} ) =
          $LIB->_sand( $x->{value}, $x->{sign}, $y->{value}, $y->{sign} );
    }

    return $x->round(@r);
}

sub bior {

    my ( $class, $x, $y, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bior');

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bior( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $r[3] = $y;

    return $x->bnan() if ( !$x->is_finite() || !$y->is_finite() );

    if ( $x->{sign} eq '+' && $y->{sign} eq '+' ) {
        $x->{value} = $LIB->_or( $x->{value}, $y->{value} );
    }
    else {
        ( $x->{value}, $x->{sign} ) =
          $LIB->_sor( $x->{value}, $x->{sign}, $y->{value}, $y->{sign} );
    }
    return $x->round(@r);
}

sub bxor {

    my ( $class, $x, $y, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bxor');

    unless ( $y->isa(__PACKAGE__) ) {
        if ( $y->is_int() ) {
            $y = $y->as_int();
        }
        else {
            return $x->_upg()->bxor( $y, @r ) if $class->upgrade();
            croak "Can't handle a ", ref($y), " in ", ( caller(0) )[3], "()";
        }
    }

    $r[3] = $y;

    return $x->bnan(@r) if !$x->is_finite() || !$y->is_finite();

    if ( $x->{sign} eq '+' && $y->{sign} eq '+' ) {
        $x->{value} = $LIB->_xor( $x->{value}, $y->{value} );
    }
    else {
        ( $x->{value}, $x->{sign} ) =
          $LIB->_sxor( $x->{value}, $x->{sign}, $y->{value}, $y->{sign} );
    }
    return $x->round(@r);
}

sub bnot {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bnot');

    $x->binc()->bneg(@r);
}

sub round {
    my ( $class, $self, @args ) =
      ref( $_[0] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 1, @_ );

    if (   @args == 1 && !defined( $args[0] )
        || @args >= 2
        && @args <= 3
        && !defined( $args[0] )
        && !defined( $args[1] ) )
    {
        $self->{accuracy}  = undef;
        $self->{precision} = undef;
        return $self;
    }

    my ( $a, $p, $r ) = splice @args, 0, 3;

    if ( defined $a ) {
        croak "accuracy must be a number, not '$a'"
          unless $a =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?\z/;
    }

    if ( defined $p ) {
        croak "precision must be a number, not '$p'"
          unless $p =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?\z/;
    }

    if ( !defined $a ) {
        foreach ( $self, @args ) {
            $a = $_->{accuracy}
              if ( defined $_->{accuracy} )
              && ( !defined $a || $_->{accuracy} < $a );
        }
    }
    if ( !defined $p ) {
        foreach ( $self, @args ) {
            $p = $_->{precision}
              if ( defined $_->{precision} )
              && ( !defined $p || $_->{precision} > $p );
        }
    }

    unless ( defined $a || defined $p ) {
        $a = $class->accuracy();
        $p = $class->precision();
    }

    $a = undef if defined $a && $a == 0;

    return $self unless defined $a || defined $p;

    if ( defined $a && defined $p ) {
        return $self->bnan();
    }

    $r = $class->round_mode() unless defined $r;
    if ( $r !~ /^(even|odd|[+-]inf|zero|trunc|common)$/ ) {
        croak("Unknown round mode '$r'");
    }

    if ( defined $a ) {
        $self->bround( int($a), $r )
          if !defined $self->{accuracy} || $self->{accuracy} >= $a;
    }
    else {
        $self->bfround( int($p), $r )
          if !defined $self->{precision} || $self->{precision} <= $p;
    }

    $self;
}

sub bround {

    my ( $class, $x, @a ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bround');

    my ( $scale, $mode ) = $x->_scale_a(@a);
    return $x if !defined $scale;

    if ( $x->is_zero() || $scale == 0 ) {
        $x->{accuracy} = $scale
          if !defined $x->{accuracy} || $x->{accuracy} > $scale;
        return $x;
    }
    return $x if !$x->is_finite();

    my $len = $x->length();
    $scale = $scale->numify() if ref($scale);

    if ( ( $scale < 0 && $scale < -$len - 1 ) || ( $scale >= $len ) ) {
        $x->{accuracy} = $scale
          if !defined $x->{accuracy} || $x->{accuracy} > $scale;
        return $x;
    }

    my ( $pad, $digit_round, $digit_after );
    $pad = $len - $scale;
    $pad = abs( $scale - 1 ) if $scale < 0;

    my $xs = $LIB->_str( $x->{value} );
    my $pl = -$pad - 1;

    $digit_round = '0';
    $digit_round = substr( $xs, $pl, 1 ) if $pad <= $len;
    $pl++;
    $pl++ if $pad >= $len;
    $digit_after = '0';
    $digit_after = substr( $xs, $pl, 1 ) if $pad > 0;

    my $round_up = 1;
    $round_up--
      if ( $mode eq 'trunc' )
      || ( $digit_after =~ /[01234]/ )
      ||

      ( $digit_after eq '5' )
      && ( $x->_scan_for_nonzero( $pad, $xs, $len ) == 0 )
      && ( ( $mode eq 'even' ) && ( $digit_round =~ /[24680]/ )
        || ( $mode eq 'odd' )  && ( $digit_round =~ /[13579]/ )
        || ( $mode eq '+inf' ) && ( $x->{sign} eq '-' )
        || ( $mode eq '-inf' ) && ( $x->{sign} eq '+' )
        || ( $mode eq 'zero' ) );
    my $put_back = 0;

    if ( ( $pad > 0 ) && ( $pad <= $len ) ) {
        substr( $xs, -$pad, $pad ) = '0' x $pad;
        $xs =~ s/^0+(\d)/$1/;
        $put_back = 1;
    }
    elsif ( $pad > $len ) {
        $x->bzero();
    }

    if ($round_up) {
        $put_back = 1;
        $pad      = $len, $xs = '0' x $pad if $scale < 0;

        my $c = 0;
        $pad++;
        while ( $pad <= $len ) {
            $c = substr( $xs, -$pad, 1 ) + 1;
            $c = '0' if $c eq '10';
            substr( $xs, -$pad, 1 ) = $c;
            $pad++;
            last if $c != 0;
        }
        $xs = '1' . $xs if $c == 0;
    }
    $x->{value} = $LIB->_new($xs) if $put_back == 1;

    $x->{accuracy} = $scale if $scale >= 0;
    if ( $scale < 0 ) {
        $x->{accuracy} = $len + $scale;
        $x->{accuracy} = 0 if $scale < -$len;
    }
    $x;
}

sub bfround {

    my ( $class, $x, @p ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bfround');

    my ( $scale, $mode ) = $x->_scale_p(@p);

    return $x if !defined $scale;

    $x = $x->bround( $x->length() - $scale, $mode ) if $scale > 0;

    $x->{accuracy}  = undef;
    $x->{precision} = $scale;
    $x;
}

sub fround {
    my $x = shift;
    $x = __PACKAGE__->new($x) unless ref $x;
    $x->bround(@_);
}

sub bfloor {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bfloor');

    $x->round(@r);
}

sub bceil {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bceil');

    $x->round(@r);
}

sub bint {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bint');

    $x->round(@r);
}

sub bgcd {

    unless (
        @_
        && (
            defined( blessed( $_[0] ) ) && $_[0]->isa(__PACKAGE__)
            || (   $_[0] =~ /^[a-z]\w*(?:::[a-z]\w*)*$/i
                && $_[0] !~ /^(inf|nan)/i )
        )
      )
    {
        unshift @_, __PACKAGE__;
    }

    my ( $class, @args ) = objectify( 0, @_ );

    for my $arg (@args) {
        return $class->bnan() unless $arg->is_int();
    }

    my $upg = $class->upgrade();
    if ($upg) {
        my $do_upgrade = 0;
        for my $arg (@args) {
            unless ( $arg->isa(__PACKAGE__) ) {
                $do_upgrade = 1;
                last;
            }
        }
        if ($do_upgrade) {
            my $x = shift @args;
            $x->_upg();
            return $x->bgcd(@args);
        }
    }

    my $x = shift @args;
    $x = $x->copy();
    while (@args) {
        my $y = shift @args;
        $x->{value} = $LIB->_gcd( $x->{value}, $y->{value} );
        last if $LIB->_is_one( $x->{value} );
    }

    return $x->babs();
}

sub blcm {

    unless (
        @_
        && (
            defined( blessed( $_[0] ) ) && $_[0]->isa(__PACKAGE__)
            || (   $_[0] =~ /^[a-z]\w*(?:::[a-z]\w*)*$/i
                && $_[0] !~ /^(inf|nan)/i )
        )
      )
    {
        unshift @_, __PACKAGE__;
    }

    my ( $class, @args ) = objectify( 0, @_ );

    for my $arg (@args) {
        return $class->bnan() unless $arg->is_finite();
    }

    for my $arg (@args) {
        return $class->bzero() if $arg->is_zero();
    }

    my $upg = $class->upgrade();
    if ($upg) {
        my $do_upgrade = 0;
        for my $arg (@args) {
            unless ( $arg->isa(__PACKAGE__) ) {
                $do_upgrade = 1;
                last;
            }
        }
        if ($do_upgrade) {
            my $x = shift @args;
            $x->_upg();
            return $x->bgcd(@args);
        }
    }

    my $x = shift @args;
    $x = $x->copy();

    while (@args) {
        my $y = shift @args;
        return $x->bnan() if !$y->is_int();
        $x->{value} = $LIB->_lcm( $x->{value}, $y->{value} );
    }

    return $x->babs();
}

sub sign {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    $x->{sign};
}

sub digit {
    my ( undef, $x, $n, @r ) =
      ref( $_[0] ) ? ( undef, @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    $n = $n->numify() if ref($n);
    $LIB->_digit( $x->{value}, $n || 0 );
}

sub bdigitsum {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bdigitsum');

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x         if $x->is_nan();
    return $x->bnan() if $x->is_inf();

    $x->{value} = $LIB->_digitsum( $x->{value} );
    $x->{sign}  = '+';
    return $x;
}

sub digitsum {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $class->bnan() if $x->is_nan();
    return $class->bnan() if $x->is_inf();

    my $y = $class->bzero();
    $y->{value} = $LIB->_digitsum( $x->{value} );
    $y->round(@r);
}

sub length {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    my $e = $LIB->_len( $x->{value} );
    wantarray ? ( $e, 0 ) : $e;
}

sub mantissa {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( !$x->is_finite() ) {
        return $class->new( $x->{sign}, @r );
    }
    my $m = $x->copy();
    $m->precision(undef);
    $m->accuracy(undef);

    my $zeros = $LIB->_zeros( $m->{value} );
    $m = $m->brsft( $zeros, 10 ) if $zeros != 0;
    $m->round(@r);
}

sub exponent {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( !$x->is_finite() ) {
        my $s = $x->{sign};
        $s =~ s/^[+-]//;
        return $class->new( $s, @r );
    }
    return $class->bzero(@r) if $x->is_zero();

    $class->new( $LIB->_zeros( $x->{value} ), @r );
}

sub parts {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    ( $x->mantissa(@r), $x->exponent(@r) );
}

sub sparts {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->is_nan() ) {
        my $mant = $class->bnan(@r);
        return $mant unless wantarray;
        my $expo = $class->bnan(@r);
        return $mant, $expo;
    }

    if ( $x->is_inf() ) {
        my $mant = $class->binf( $x->{sign}, @r );
        return $mant unless wantarray;
        my $expo = $class->binf( '+', @r );
        return $mant, $expo;
    }

    my $mant   = $x->copy();
    my $nzeros = $LIB->_zeros( $mant->{value} );

    $mant->{value} = $LIB->_rsft( $mant->{value}, $LIB->_new($nzeros), 10 )
      if $nzeros != 0;
    return $mant unless wantarray;

    my $expo = $class->new( $nzeros, @r );
    return $mant, $expo;
}

sub nparts {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->sparts(@r) if $x->is_nan() || $x->is_inf();

    my ( $mant, $expo ) = $x->sparts(@r);
    if ( $mant->bcmp(0) ) {
        my ( $ndigtot, $ndigfrac ) = $mant->length();
        my $expo10adj = $ndigtot - $ndigfrac - 1;

        if ( $expo10adj > 0 ) {
            return $x->_upg()->nparts(@r) if $class->upgrade();
            $mant->bnan(@r);
            return $mant unless wantarray;
            $expo->badd( $expo10adj, @r );
            return $mant, $expo;
        }
    }

    return $mant unless wantarray;
    return $mant, $expo;
}

sub eparts {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->sparts(@r) if $x->is_nan() || $x->is_inf();

    my ( $mant, $expo ) = $x->sparts(@r);

    if ( $mant->bcmp(0) ) {
        my $ndigmant = $mant->length();
        $expo->badd( $ndigmant, @r );

        my $c = $expo->copy()->bdec()->bmod(3)->binc();
        $expo->bsub($c);

        if ( $ndigmant > $c ) {
            return $x->_upg()->eparts(@r) if $class->upgrade();
            $mant->bnan(@r);
            return $mant unless wantarray;
            return $mant, $expo;
        }

        $mant->blsft( $c - $ndigmant, 10, @r );
    }

    return $mant unless wantarray;
    return $mant, $expo;
}

sub dparts {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->is_nan() ) {
        my $int = $class->bnan(@r);
        return $int unless wantarray;
        my $frc = $class->bzero(@r);
        return $int, $frc;
    }

    if ( $x->is_inf() ) {
        my $int = $class->binf( $x->{sign}, @r );
        return $int unless wantarray;
        my $frc = $class->bzero(@r);
        return $int, $frc;
    }

    my $int = $x->copy()->round(@r);
    return $int unless wantarray;

    my $frc = $class->bzero(@r);
    return $int, $frc;
}

sub fparts {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->is_nan() ) {
        return $class->bnan(@r) unless wantarray;
        return $class->bnan(@r), $class->bnan(@r);
    }

    if ( $x->is_inf() ) {
        my $numer = $class->binf( $x->{sign}, @r );
        return $numer unless wantarray;
        my $denom = $class->bone(@r);
        return $numer, $denom;
    }

    my $numer = $x->copy()->round(@r);
    return $numer unless wantarray;
    my $denom = $class->bone(@r);
    return $numer, $denom;
}

sub numerator {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->copy()->round(@r);
}

sub denominator {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->is_nan() ? $class->bnan(@r) : $class->bone(@r);
}

sub bstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bstr(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $str = $LIB->_str( $x->{value} );
    return $x->{sign} eq '-' ? "-$str" : $str;
}

sub bsstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bsstr(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $expo = $LIB->_zeros( $x->{value} );
    my $mant = $LIB->_str( $x->{value} );
    $mant = substr( $mant, 0, -$expo ) if $expo;

    ( $x->{sign} eq '-' ? '-' : '' ) . $mant . 'e+' . $expo;
}

sub bnstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bnstr(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $expo = $LIB->_zeros( $x->{value} );
    my $mant = $LIB->_str( $x->{value} );
    $mant = substr( $mant, 0, -$expo ) if $expo;

    my $mantlen = CORE::length($mant);
    if ( $mantlen > 1 ) {
        $expo += $mantlen - 1;
        substr $mant, 1, 0, ".";
    }

    ( $x->{sign} eq '-' ? '-' : '' ) . $mant . 'e+' . $expo;
}

sub bestr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bestr(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $expo = $LIB->_zeros( $x->{value} );
    my $mant = $LIB->_str( $x->{value} );
    $mant = substr( $mant, 0, -$expo ) if $expo;
    my $mantlen = CORE::length($mant);
    $expo += $mantlen;

    my $dotpos = ( $expo - 1 ) % 3 + 1;
    $expo -= $dotpos;

    if ( $dotpos < $mantlen ) {
        substr $mant, $dotpos, 0, ".";
    }
    elsif ( $dotpos > $mantlen ) {
        $mant .= "0" x ( $dotpos - $mantlen );
    }

    ( $x->{sign} eq '-' ? '-' : '' ) . $mant . 'e+' . $expo;
}

sub bdstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bdstr(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    ( $x->{sign} eq '-' ? '-' : '' ) . $LIB->_str( $x->{value} );
}

sub bfstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bfstr(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    ( $x->{sign} eq '-' ? '-' : '' ) . $LIB->_str( $x->{value} );
}

sub to_hex {

    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $x->_upg()->to_hex(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $hex = $LIB->_to_hex( $x->{value} );
    return $x->{sign} eq '-' ? "-$hex" : $hex;
}

sub to_oct {

    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $x->_upg()->to_oct(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $oct = $LIB->_to_oct( $x->{value} );
    return $x->{sign} eq '-' ? "-$oct" : $oct;
}

sub to_bin {

    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $x->_upg()->to_bin(@r) if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $bin = $LIB->_to_bin( $x->{value} );
    return $x->{sign} eq '-' ? "-$bin" : $bin;
}

sub to_bytes {

    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    croak("to_bytes() requires a finite, non-negative integer")
      if $x->is_neg() || !$x->is_int();

    return $x->_upg()->to_bytes(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    croak("to_bytes() requires a newer version of the $LIB library.")
      unless $LIB->can('_to_bytes');

    return $LIB->_to_bytes( $x->{value} );
}

sub to_ieee754 {
    my ( $class, $x, $format, @r ) =
      ref( $_[0] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->_upg()->to_ieee754( $format, @r )
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    croak("the value to convert must be an integer, +/-infinity, or NaN")
      unless $x->is_int() || $x->is_inf() || $x->is_nan();

    return $x->as_float()->to_ieee754($format);
}

sub to_base {

    my ( $class, $x, $base, $cs, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    croak("the value to convert must be a finite, non-negative integer")
      if $x->is_neg() || !$x->is_int();

    croak("the base must be a finite integer >= 2")
      if $base < 2 || !$base->is_int();

    unless ( defined $cs ) {
        return $x->to_bin()    if $base == 2;
        return $x->to_oct()    if $base == 8;
        return uc $x->to_hex() if $base == 16;
        return $x->bstr()      if $base == 10;
    }

    croak("to_base() requires a newer version of the $LIB library.")
      unless $LIB->can('_to_base');

    return $x->_upg()->to_basen( $base, $cs, @r )
      if $class->upgrade()
      && ( !$x->isa(__PACKAGE__)
        || !$base->isa(__PACKAGE__) );

    return $LIB->_to_base( $x->{value}, $base->{value},
        defined($cs) ? $cs : () );
}

sub to_base_num {

    my ( $class, $x, $base, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    croak("the value to convert must be a finite non-negative integer")
      if $x->is_neg() || !$x->is_int();

    croak("the base must be a finite integer >= 2")
      if $base < 2 || !$base->is_int();

    croak("to_base() requires a newer version of the $LIB library.")
      unless $LIB->can('_to_base');

    return $x->_upg()->to_base_num( $base, @r )
      if $class->upgrade()
      && ( !$x->isa(__PACKAGE__)
        || !$base->isa(__PACKAGE__) );

    my $vals = $LIB->_to_base_num( $x->{value}, $base->{value} );

    for my $i ( 0 .. $#$vals ) {
        my $x = $class->bzero();
        $x->{value} = $vals->[$i];
        $vals->[$i] = $x;
    }

    return $vals;
}

sub as_hex {

    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->bstr() if !$x->is_finite();

    return $x->_upg()->as_hex(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $hex = $LIB->_as_hex( $x->{value} );
    return $x->{sign} eq '-' ? "-$hex" : $hex;
}

sub as_oct {

    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->bstr() if !$x->is_finite();

    return $x->_upg()->as_oct(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $oct = $LIB->_as_oct( $x->{value} );
    return $x->{sign} eq '-' ? "-$oct" : $oct;
}

sub as_bin {

    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->bstr() if !$x->is_finite();

    return $x->_upg()->as_bin(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $bin = $LIB->_as_bin( $x->{value} );
    return $x->{sign} eq '-' ? "-$bin" : $bin;
}

*as_bytes = \&to_bytes;

sub numify {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( $x->is_nan() ) {
        require Math::Complex;
        my $inf = $Math::Complex::Inf;
        return $inf - $inf;
    }

    if ( $x->is_inf() ) {
        require Math::Complex;
        my $inf = $Math::Complex::Inf;
        return $x->is_negative() ? -$inf : $inf;
    }

    return $x->_upg()->numify(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    my $num = 0 + $LIB->_num( $x->{value} );
    return $x->{sign} eq '-' ? -$num : $num;
}

sub _trailing_zeros {
    my $x = shift;
    $x = __PACKAGE__->new($x) unless ref $x;

    return 0 if !$x->is_finite();

    $LIB->_zeros( $x->{value} );
}

sub _scan_for_nonzero {
    my ( $x, $pad, $xs, $len ) = @_;

    return 0 if $len == 1;
    my $follow = $pad - 1;
    return 0 if $follow > $len || $follow < 1;

    substr( $xs, -$follow ) =~ /[^0]/ ? 1 : 0;
}

sub _find_round_parameters {

    my ( $self, $a, $p, $r, @args ) = @_;

    my $class = ref($self);

    $a = $a->can('numify') ? $a->numify() : "$a" if defined $a && ref($a);
    $p = $p->can('numify') ? $p->numify() : "$p" if defined $p && ref($p);

    if ( !defined $a ) {
        foreach ( $self, @args ) {
            $a = $_->{accuracy}
              if ( defined $_->{accuracy} )
              && ( !defined $a || $_->{accuracy} < $a );
        }
    }
    if ( !defined $p ) {
        foreach ( $self, @args ) {
            $p = $_->{precision}
              if ( defined $_->{precision} )
              && ( !defined $p || $_->{precision} > $p );
        }
    }

    $a = $class->accuracy()  unless defined $a;
    $p = $class->precision() unless defined $p;

    $a = undef if defined $a && $a == 0;

    return ($self) unless defined $a || defined $p;

    return ( $self->bnan() ) if defined $a && defined $p;

    $r = $class->round_mode() unless defined $r;
    if ( $r !~ /^(even|odd|[+-]inf|zero|trunc|common)$/ ) {
        croak("Unknown round mode '$r'");
    }

    $a = int($a) if defined $a;
    $p = int($p) if defined $p;

    ( $self, $a, $p, $r );
}

sub _is_numeric {
    shift;
    my $value = shift;
    no warnings 'numeric';
    return unless CORE::length( ( my $dummy = "" ) & $value );
    return unless 0 + $value eq $value;
    return 1 if $value * 0 == 0;
    return -1;
}

sub _trim_split_parts {
    shift;

    my $sig_sgn = shift() || '+';
    my $sig_str = shift() || '0';
    my $exp_sgn = shift() || '+';
    my $exp_str = shift() || '0';

    $sig_str =~ tr/_//d;
    $sig_str =~ s/^0+//;
    $sig_str =~ s/\.0*$//
      || $sig_str =~ s/(\..*[^0])0+$/$1/;
    $sig_str = '0' unless CORE::length($sig_str);

    return '+', '0', '+', '0' if $sig_str eq '0';

    $exp_str =~ tr/_//d;
    $exp_str =~ s/^0+//;
    $exp_str = '0' unless CORE::length($exp_str);
    $exp_sgn = '+' if $exp_str eq '0';

    return $sig_sgn, $sig_str, $exp_sgn, $exp_str;
}

sub _dec_str_to_dec_str_parts {
    my $class = shift;
    my $str   = shift;

    if (
        $str =~ /
                    ^

                    # optional leading whitespace
                    \s*

                    # optional sign
                    ( [+-]? )

                    # significand
                    (
                        # integer part and optional fraction part ...
                        \d+ (?: _+ \d+ )* _*
                        (?:
                            \.
                            (?: _* \d+ (?: _+ \d+ )* _* )?
                        )?
                    |
                        # ... or mandatory fraction part
                        \.
                        \d+ (?: _+ \d+ )* _*
                    )

                    # optional exponent
                    (?:
                        [Ee]
                        ( [+-]? )
                        ( \d+ (?: _+ \d+ )* _* )
                    )?

                    # optional trailing whitespace
                    \s*

                    $
                /x
      )
    {
        return $class->_trim_split_parts( $1, $2, $3, $4 );
    }

    return;
}

sub _hex_str_to_hex_str_parts {
    my $class = shift;
    my $str   = shift;

    if (
        $str =~ /
                    ^

                    # optional leading whitespace
                    \s*

                    # optional sign
                    ( [+-]? )

                    # optional hex prefix
                    (?: 0? [Xx] _* )?

                    # significand using the hex digits 0..9 and a..f
                    (
                        # integer part and optional fraction part ...
                        [0-9a-fA-F]+ (?: _+ [0-9a-fA-F]+ )* _*
                        (?:
                            \.
                            (?: _* [0-9a-fA-F]+ (?: _+ [0-9a-fA-F]+ )* _* )?
                        )?
                    |
                        # ... or mandatory fraction part
                        \.
                        [0-9a-fA-F]+ (?: _+ [0-9a-fA-F]+ )* _*
                    )

                    # optional exponent (power of 2) using decimal digits
                    (?:
                        [Pp]
                        ( [+-]? )
                        ( \d+ (?: _+ \d+ )* _* )
                    )?

                    # optional trailing whitespace
                    \s*

                    $
                /x
      )
    {
        return $class->_trim_split_parts( $1, $2, $3, $4 );
    }

    return;
}

sub _oct_str_to_oct_str_parts {
    my $class = shift;
    my $str   = shift;

    if (
        $str =~ /
                    ^

                    # optional leading whitespace
                    \s*

                    # optional sign
                    ( [+-]? )

                    # optional octal prefix
                    (?: 0? [Oo] _* )?

                    # significand using the octal digits 0..7
                    (
                        # integer part and optional fraction part ...
                        [0-7]+ (?: _+ [0-7]+ )* _*
                        (?:
                            \.
                            (?: _* [0-7]+ (?: _+ [0-7]+ )* _* )?
                        )?
                    |
                        # ... or mandatory fraction part
                        \.
                        [0-7]+ (?: _+ [0-7]+ )* _*
                    )

                    # optional exponent (power of 2) using decimal digits
                    (?:
                        [Pp]
                        ( [+-]? )
                        ( \d+ (?: _+ \d+ )* _* )
                    )?

                    # optional trailing whitespace
                    \s*

                    $
                /x
      )
    {
        return $class->_trim_split_parts( $1, $2, $3, $4 );
    }

    return;
}

sub _bin_str_to_bin_str_parts {
    my $class = shift;
    my $str   = shift;

    if (
        $str =~ /
                    ^

                    # optional leading whitespace
                    \s*

                    # optional sign
                    ( [+-]? )

                    # optional binary prefix
                    (?: 0? [Bb] _* )?

                    # significand using the binary digits 0 and 1
                    (
                        # integer part and optional fraction part ...
                        [01]+ (?: _+ [01]+ )* _*
                        (?:
                            \.
                            (?: _* [01]+ (?: _+ [01]+ )* _* )?
                        )?
                    |
                        # ... or mandatory fraction part
                        \.
                        [01]+ (?: _+ [01]+ )* _*
                    )

                    # optional exponent (power of 2) using decimal digits
                    (?:
                        [Pp]
                        ( [+-]? )
                        ( \d+ (?: _+ \d+ )* _* )
                    )?

                    # optional trailing whitespace
                    \s*

                    $
                /x
      )
    {
        return $class->_trim_split_parts( $1, $2, $3, $4 );
    }

    return;
}

sub _dec_str_parts_to_flt_lib_parts {
    shift;

    my ( $sig_sgn, $sig_str, $exp_sgn, $exp_str ) = @_;

    if ( $sig_str eq '0' ) {
        return '+', $LIB->_zero(), '+', $LIB->_zero();
    }

    my $exp_lib = $LIB->_new($exp_str);

    my $idx = index $sig_str, '.';
    if ( $idx >= 0 ) {
        substr( $sig_str, $idx, 1 ) = '';

        my $delta = $LIB->_new( CORE::length($sig_str) );
        $delta = $LIB->_sub( $delta, $LIB->_new($idx) );

        ( $exp_lib, $exp_sgn ) = $LIB->_ssub( $exp_lib, $exp_sgn, $delta, '+' );

        $sig_str =~ s/^0+//;
    }

    if ( $sig_str =~ s/(0+)\z// ) {
        my $len = CORE::length($1);
        ( $exp_lib, $exp_sgn ) =
          $LIB->_sadd( $exp_lib, $exp_sgn, $LIB->_new($len), '+' );
    }

    unless ( CORE::length $sig_str ) {
        return '+', $LIB->_zero(), '+', $LIB->_zero();
    }

    my $sig_lib = $LIB->_new($sig_str);

    return $sig_sgn, $sig_lib, $exp_sgn, $exp_lib;
}

sub _bin_str_parts_to_flt_lib_parts {
    shift;

    my ( $sig_sgn, $sig_str, $exp_sgn, $exp_str, $bpc ) = @_;
    my $bpc_lib = $LIB->_new($bpc);

    if ( $sig_str eq '0' ) {
        return '+', $LIB->_zero(), '+', $LIB->_zero();
    }

    my $exp_lib = $LIB->_new($exp_str);

    my $idx = index $sig_str, '.';
    if ( $idx >= 0 ) {
        substr( $sig_str, $idx, 1 ) = '';

        my $delta = $LIB->_new( CORE::length($sig_str) );
        $delta = $LIB->_sub( $delta, $LIB->_new($idx) );
        $delta = $LIB->_mul( $delta, $bpc_lib ) if $bpc != 1;

        ( $exp_lib, $exp_sgn ) = $LIB->_ssub( $exp_lib, $exp_sgn, $delta, '+' );

        $sig_str =~ s/^0+//;
    }

    if ( $sig_str =~ s/(0+)\z// ) {

        my $delta = $LIB->_new( CORE::length($1) );
        $delta = $LIB->_mul( $delta, $bpc_lib ) if $bpc != 1;

        ( $exp_lib, $exp_sgn ) = $LIB->_sadd( $exp_lib, $exp_sgn, $delta, '+' );
    }

    unless ( CORE::length $sig_str ) {
        return '+', $LIB->_zero(), '+', $LIB->_zero();
    }

    my $sig_lib =
        $bpc == 1 ? $LIB->_from_bin( '0b' . $sig_str )
      : $bpc == 3 ? $LIB->_from_oct( '0' . $sig_str )
      : $bpc == 4 ? $LIB->_from_hex( '0x' . $sig_str )
      :             die "internal error: invalid exponent multiplier";

    if ( $exp_sgn eq '+' ) {

        if ( !$LIB->_is_zero($exp_lib) ) {

            my $p = $LIB->_pow( $LIB->_two(), $exp_lib );
            $sig_lib = $LIB->_mul( $sig_lib, $p );
            $exp_lib = $LIB->_zero();
        }
    }

    else {

        my $p = $LIB->_pow( $LIB->_new("5"), $exp_lib );
        $sig_lib = $LIB->_mul( $sig_lib, $p );
    }

    my $n = $LIB->_zeros($sig_lib);
    if ($n) {
        $n       = $LIB->_new($n);
        $sig_lib = $LIB->_rsft( $sig_lib, $n, 10 );
        ( $exp_lib, $exp_sgn ) = $LIB->_sadd( $exp_lib, $exp_sgn, $n, '+' );
    }

    return $sig_sgn, $sig_lib, $exp_sgn, $exp_lib;
}

sub _hex_str_to_flt_lib_parts {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_hex_str_to_hex_str_parts($str) ) {
        return $class->_bin_str_parts_to_flt_lib_parts( @parts, 4 );
    }
    return;
}

sub _oct_str_to_flt_lib_parts {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_oct_str_to_oct_str_parts($str) ) {
        return $class->_bin_str_parts_to_flt_lib_parts( @parts, 3 );
    }
    return;
}

sub _bin_str_to_flt_lib_parts {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_bin_str_to_bin_str_parts($str) ) {
        return $class->_bin_str_parts_to_flt_lib_parts( @parts, 1 );
    }
    return;
}

sub _dec_str_to_flt_lib_parts {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_dec_str_to_dec_str_parts($str) ) {
        return $class->_dec_str_parts_to_flt_lib_parts(@parts);
    }
    return;
}

sub dec_str_to_dec_flt_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_dec_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_flt_str(@parts);
    }
    return;
}

sub hex_str_to_dec_flt_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_hex_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_flt_str(@parts);
    }
    return;
}

sub oct_str_to_dec_flt_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_oct_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_flt_str(@parts);
    }
    return;
}

sub bin_str_to_dec_flt_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_bin_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_flt_str(@parts);
    }
    return;
}

sub dec_str_to_dec_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_dec_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_dec_str(@parts);
    }
    return;
}

sub hex_str_to_dec_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_dec_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_dec_str(@parts);
    }
    return;
}

sub oct_str_to_dec_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_oct_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_dec_str(@parts);
    }
    return;
}

sub bin_str_to_dec_str {
    my $class = shift;
    my $str   = shift;
    if ( my @parts = $class->_bin_str_to_flt_lib_parts($str) ) {
        return $class->_flt_lib_parts_to_dec_str(@parts);
    }
    return;
}

sub _flt_lib_parts_to_flt_str {
    my $class = shift;
    my @parts = @_;
    return
        $parts[0]
      . $LIB->_str( $parts[1] ) . 'e'
      . $parts[2]
      . $LIB->_str( $parts[3] );
}

sub _flt_lib_parts_to_dec_str {
    my $class = shift;
    my @parts = @_;

    if ( $parts[2] eq '+' ) {
        my $str =
          $parts[0] . $LIB->_str( $LIB->_lsft( $parts[1], $parts[3], 10 ) );
        return $str;
    }

    else {
        my $mant     = $LIB->_str( $parts[1] );
        my $mant_len = CORE::length($mant);
        my $expo     = $LIB->_num( $parts[3] );
        my $len_cmp  = $mant_len <=> $expo;
        if ( $len_cmp <= 0 ) {
            return $parts[0] . '0.' . '0' x ( $expo - $mant_len ) . $mant;
        }
        else {
            substr $mant, $mant_len - $expo, 0, '.';
            return $parts[0] . $mant;
        }
    }
}

sub _flt_lib_parts_to_rat_lib_parts {
    my $self = shift;
    my ( $msgn, $mabs, $esgn, $eabs ) = @_;

    if ( $esgn eq '-' ) {
        my $num_lib = $LIB->_copy($mabs);
        my $den_lib = $LIB->_1ex( $LIB->_num($eabs) );
        my $gcd_lib = $LIB->_gcd( $LIB->_copy($num_lib), $den_lib );
        $num_lib = $LIB->_div( $LIB->_copy($num_lib), $gcd_lib );
        $den_lib = $LIB->_div( $den_lib,              $gcd_lib );
        return $msgn, $num_lib, $den_lib;
    }

    elsif ( !$LIB->_is_zero($eabs) ) {
        return $msgn, $LIB->_lsft( $LIB->_copy($mabs), $eabs, 10 ),
          $LIB->_one();
    }

    else {
        return $msgn, $mabs, $LIB->_one();
    }
}

sub _register_callback { }

sub objectify {

    return ( ref( $_[1] ), $_[1] )
      if @_ == 2 && ( $_[0] || 0 ) == 1 && ref( $_[1] );

    unless (wantarray) {
        croak( __PACKAGE__ . "::objectify() needs list context" );
    }

    my $count = shift;

    my @a = @_;

    my $class;
    if ( ref( $a[0] ) ) {
        $class = ref( $a[0] );
    }
    elsif ( $a[0] =~ /^[A-Z].*::/ ) {
        $class = shift @a;
    }
    else {
        $class = __PACKAGE__;
    }

    $count ||= @a;
    unshift @a, $class;

    my @upg                = ();
    my $have_upgrade_chain = 0;

    my $dng = $class->downgrade();
    $class->downgrade(undef);

  ARG: for my $i ( 1 .. $count ) {

        my $ref = ref $a[$i];

        unless ($ref) {
            $a[$i] = $class->new( $a[$i] );
            next;
        }

        next if $ref->isa($class);

        unless ($have_upgrade_chain) {
            my $cls = $class;
            my $upg = $cls->upgrade();
            while ( defined $upg ) {
                last if $upg eq $cls;
                push @upg, $upg;
                $cls = $upg;
                $upg = $cls->upgrade();
            }
            $have_upgrade_chain = 1;
        }

        for my $upg (@upg) {
            next ARG if $ref->isa($upg);
        }

        my $recheck = 0;

        if ( $class->isa('Math::BigInt') ) {
            if ( $a[$i]->can('as_int') ) {
                $a[$i] = $a[$i]->as_int();
                $recheck = 1;
            }
            elsif ( $a[$i]->can('as_number') ) {
                $a[$i] = $a[$i]->as_number();
                $recheck = 1;
            }
        }

        elsif ( $class->isa('Math::BigRat') ) {
            if ( $a[$i]->can('as_rat') ) {
                $a[$i] = $a[$i]->as_rat();
                $recheck = 1;
            }
        }

        elsif ( $class->isa('Math::BigFloat') ) {
            if ( $a[$i]->can('as_float') ) {
                $a[$i] = $a[$i]->as_float();
                $recheck = 1;
            }
        }

        if ($recheck) {
            $ref = ref( $a[$i] );

            unless ($ref) {
                $a[$i] = $class->new( $a[$i] );
                next;
            }

            next if $ref->isa($class);
        }

        $a[$i] = $class->new( $a[$i] );
    }

    $class->downgrade($dng);

    return @a;
}

sub import {
    my $class = shift;
    $IMPORT++;
    my @a;

    while (@_) {
        my $param = shift;

        if ( $param eq ':constant' ) {
            overload::constant

              integer => sub {
                $class->new(shift);
              },

              float => sub {
                $class->new(shift);
              },

              binary => sub {
                return $class->from_oct( $_[0] ) if $_[0] =~ /^0_*[0-7]/;
                $class->new(shift);
              };
            next;
        }

        if ( $param eq 'upgrade' ) {
            $class->upgrade(shift);
            next;
        }

        if ( $param eq 'downgrade' ) {
            $class->downgrade(shift);
            next;
        }

        if ( $param eq 'accuracy' ) {
            $class->accuracy(shift);
            next;
        }

        if ( $param eq 'precision' ) {
            $class->precision(shift);
            next;
        }

        if ( $param eq 'round_mode' ) {
            $class->round_mode(shift);
            next;
        }

        if ( $param eq 'div_scale' ) {
            $class->div_scale(shift);
            next;
        }

        if ( $param =~ /^(lib|try|only)\z/ ) {

            croak "Library argument for import parameter '$param' is missing"
              unless @_;
            my $libs = shift;
            croak "Library argument for import parameter '$param' is undefined"
              unless defined($libs);

            my @libs;
            for my $lib ( split /,/, $libs ) {
                $lib =~ s/^\s+//;
                $lib =~ s/\s+$//;

                if ( $lib =~ /[^a-zA-Z0-9_:]/ ) {
                    carp "Library name '$lib' contains invalid characters";
                    next;
                }

                if ( !CORE::length $lib ) {
                    carp "Library name is empty";
                    next;
                }

                $lib = "Math::BigInt::$lib" if $lib !~ /^Math::BigInt::/i;

                if ( defined($LIB) ) {
                    if ( $lib ne $LIB ) {
                    }
                    next;
                }

                push @libs, $lib;
            }

            next if defined $LIB;

            croak "Library list contains no valid libraries" unless @libs;

            for ( my $i = 0 ; $i <= $#libs ; $i++ ) {
                my $lib = $libs[$i];
                eval "require $lib";
                unless ($@) {
                    $LIB = $lib;
                    last;
                }
            }

            next if defined $LIB;

            if ( $param eq 'only' ) {
                croak "Couldn't load the specified math lib(s) ",
                  join( ", ", map "'$_'", @libs ),
                  ", and fallback to '$DEFAULT_LIB' is not allowed";
            }

            eval "require $DEFAULT_LIB";
            if ($@) {
                croak "Couldn't load the specified math lib(s) ",
                  join( ", ", map "'$_'", @libs ),
                  ", not even the fallback lib '$DEFAULT_LIB'";
            }

            if ( $param eq 'lib' ) {
                carp "Couldn't load the specified math lib(s) ",
                  join( ", ", map "'$_'", @libs ),
                  ", so using fallback lib '$DEFAULT_LIB'";
            }

            next;
        }

        push @a, $param;
    }

    $class->SUPER::import(@a);
    $class->export_to_level( 1, $class, @a ) if @a;

    unless ( defined $LIB ) {
        eval "require $DEFAULT_LIB";
        if ($@) {
            croak "No lib specified, and couldn't load the default",
              " lib '$DEFAULT_LIB'";
        }
        $LIB = $DEFAULT_LIB;
    }

}

1;

__END__

