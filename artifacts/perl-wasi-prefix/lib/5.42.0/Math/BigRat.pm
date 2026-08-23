
package Math::BigRat;

use 5.006;
use strict;
use warnings;

use Carp           qw< carp croak >;
use Scalar::Util   qw< blessed >;
use Math::BigFloat qw<>;

our $VERSION = '2.005002';
$VERSION =~ tr/_//d;

require Exporter;
our @ISA = qw< Math::BigFloat >;

use overload

  '+' => sub { $_[0]->copy()->badd( $_[1] ); },

  '-' => sub {
    my $c = $_[0]->copy;
    $_[2]
      ? $c->bneg()->badd( $_[1] )
      : $c->bsub( $_[1] );
  },

  '*' => sub { $_[0]->copy()->bmul( $_[1] ); },

  '/' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bfdiv( $_[0] )
      : $_[0]->copy()->bfdiv( $_[1] );
  },

  '%' => sub {
    $_[2]
      ? ref( $_[0] )->new( $_[1] )->bfmod( $_[0] )
      : $_[0]->copy()->bfmod( $_[1] );
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

  '/=' => sub { scalar $_[0]->bfdiv( $_[1] ); },

  '%=' => sub { $_[0]->bfmod( $_[1] ); },

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

BEGIN {
    *objectify = \&Math::BigInt::objectify;

    *AUTOLOAD  = \&Math::BigFloat::AUTOLOAD;
    *as_number = \&as_int;
    *is_pos    = \&is_positive;
    *is_neg    = \&is_negative;
}

our $accuracy   = undef;
our $precision  = undef;
our $round_mode = 'even';
our $div_scale  = 40;

our $upgrade   = undef;
our $downgrade = undef;

our $_trap_nan = 0;
our $_trap_inf = 0;

my $nan = 'NaN';

my $LIB = Math::BigInt->config('lib');

my $IMPORT = 0;

sub isa {
    return 0 if $_[1] =~ /^Math::Big(Int|Float)/;
    UNIVERSAL::isa(@_);
}

sub new {

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    if ( @_ > 2 ) {
        carp("Superfluous arguments to new() ignored.");
    }

    if (   @_ == 0
        || @_ == 1 && !defined( $_[0] )
        || @_ == 2 && ( !defined( $_[0] ) || !defined( $_[1] ) ) )
    {
        return $class->bzero();
    }

    my @args = @_;

    $self = bless {}, $class;

    if ( @args == 1 && !ref( $args[0] ) ) {

        if (
            $args[0] =~ m{
                             ^
                             \s*

                             # optional sign
                             ( [+-]? )

                             # integer mantissa with optional leading zeros
                             0* ( [1-9] \d* (?: _ \d+ )* | 0 )

                             # optional non-negative exponent
                             (?: [eE] \+? ( \d+ (?: _ \d+ )* ) )?

                             \s*
                             $
                        }x
          )
        {
            my $sign = $1;
            ( my $mant = $2 ) =~ tr/_//d;
            my $expo = $3;
            $mant .= "0" x $expo if defined($expo) && $mant ne "0";

            $self->{_n}   = $LIB->_new($mant);
            $self->{_d}   = $LIB->_one();
            $self->{sign} = $sign eq "-" && $mant ne "0" ? "-" : "+";
            $self->_dng();
            return $self;
        }

        if (
            $args[0] =~ m{
                             ^
                             \s*

                             # optional leading sign
                             ( [+-]? )

                             # integer mantissa with optional leading zeros
                             0* ( [1-9] \d* (?: _ \d+ )* | 0 )

                             # optional non-negative exponent
                             (?: [eE] \+? ( \d+ (?: _ \d+ )* ) )?

                             # fraction
                             \s* / \s*

                             # non-zero integer mantissa with optional leading zeros
                             0* ( [1-9] \d* (?: _ \d+ )* )

                             # optional non-negative exponent
                             (?: [eE] \+? ( \d+ (?: _ \d+ )* ) )?

                             \s*
                             $
                        }x
          )
        {
            my $sign = $1;

            ( my $mant1 = $2 ) =~ tr/_//d;
            my $expo1 = $3;
            $mant1 .= "0" x $expo1 if defined($expo1) && $mant1 ne "0";

            ( my $mant2 = $4 ) =~ tr/_//d;
            my $expo2 = $5;
            $mant2 .= "0" x $expo2 if defined($expo2) && $mant2 ne "0";

            $self->{_n}   = $LIB->_new($mant1);
            $self->{_d}   = $LIB->_new($mant2);
            $self->{sign} = $sign eq "-" && $mant1 ne "0" ? "-" : "+";

            my $gcd = $LIB->_gcd( $LIB->_copy( $self->{_n} ), $self->{_d} );
            unless ( $LIB->_is_one($gcd) ) {
                $self->{_n} = $LIB->_div( $self->{_n}, $gcd );
                $self->{_d} = $LIB->_div( $self->{_d}, $gcd );
            }

            $self->_dng() if $self->is_int();
            return $self;
        }

    }

    if (   @args == 1
        && !ref( $args[0] )
        && $args[0] =~ m{ ^ \s* ( \S+ ) \s* / \s* ( \S+ ) \s* $ }x )
    {
        @args = ( $1, $2 );
    }

    my ( $n, $d );

    if ( @args >= 1 ) {
        if ( ref( $args[0] ) && $args[0]->can('as_rat') ) {
            $n = $args[0]->as_rat();
        }
        else {
            $n = Math::BigFloat->new( $args[0], undef, undef )->as_rat();
        }
    }

    if ( @args >= 2 ) {
        if ( ref( $args[1] ) && $args[1]->can('as_rat') ) {
            $d = $args[1]->as_rat();
        }
        else {
            $d = Math::BigFloat->new( $args[1], undef, undef )->as_rat();
        }
    }

    $n->bdiv($d) if defined $d;

    $self->{sign} = $n->{sign};
    $self->{_n}   = $n->{_n};
    $self->{_d}   = $n->{_d};

    $self->_dng() if ( $self->is_int()
        || $self->is_inf()
        || $self->is_nan() );
    return $self;
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
            $self->_init();
        }

        my ( $mant_sgn, $mant_abs, $expo_sgn, $expo_abs ) = @parts;

        $self->{sign} = $mant_sgn;
        $self->{_n}   = $mant_abs;

        if ( $expo_sgn eq "+" ) {
            $self->{_n} = $LIB->_lsft( $self->{_n}, $expo_abs, 10 );
            $self->{_d} = $LIB->_one();
        }
        else {
            $self->{_d} = $LIB->_1ex($expo_abs);
        }

        my $gcd = $LIB->_gcd( $LIB->_copy( $self->{_n} ), $self->{_d} );
        if ( !$LIB->_is_one($gcd) ) {
            $self->{_n} = $LIB->_div( $self->{_n}, $gcd );
            $self->{_d} = $LIB->_div( $self->{_d}, $gcd );
        }

        $self->_dng() if $self->is_int();
        return $self;
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
            $self->_init();
        }

        my ( $mant_sgn, $mant_abs, $expo_sgn, $expo_abs ) = @parts;

        $self->{sign} = $mant_sgn;
        $self->{_n}   = $mant_abs;

        if ( $expo_sgn eq "+" ) {

            $self->{_n} = $LIB->_lsft( $self->{_n}, $expo_abs, 10 );
            $self->{_d} = $LIB->_one();

        }
        else {

            $self->{_d} = $LIB->_1ex($expo_abs);

            my $gcd = $LIB->_gcd( $LIB->_copy( $self->{_n} ), $self->{_d} );
            unless ( $LIB->_is_one($gcd) ) {
                $self->{_n} = $LIB->_div( $self->{_n}, $gcd );
                $self->{_d} = $LIB->_div( $self->{_d}, $gcd );
            }
        }

        $self->_dng() if $self->is_int();
        return $self;
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
            $self->_init();
        }

        my ( $mant_sgn, $mant_abs, $expo_sgn, $expo_abs ) = @parts;

        $self->{sign} = $mant_sgn;
        $self->{_n}   = $mant_abs;

        if ( $expo_sgn eq "+" ) {

            $self->{_n} = $LIB->_lsft( $self->{_n}, $expo_abs, 10 );
            $self->{_d} = $LIB->_one();

        }
        else {

            $self->{_d} = $LIB->_1ex($expo_abs);

            my $gcd = $LIB->_gcd( $LIB->_copy( $self->{_n} ), $self->{_d} );
            unless ( $LIB->_is_one($gcd) ) {
                $self->{_n} = $LIB->_div( $self->{_n}, $gcd );
                $self->{_d} = $LIB->_div( $self->{_d}, $gcd );
            }
        }

        $self->_dng() if $self->is_int();
        return $self;
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
            $self->_init();
        }

        my ( $mant_sgn, $mant_abs, $expo_sgn, $expo_abs ) = @parts;

        $self->{sign} = $mant_sgn;
        $self->{_n}   = $mant_abs;

        if ( $expo_sgn eq "+" ) {

            $self->{_n} = $LIB->_lsft( $self->{_n}, $expo_abs, 10 );
            $self->{_d} = $LIB->_one();

        }
        else {

            $self->{_d} = $LIB->_1ex($expo_abs);

            my $gcd = $LIB->_gcd( $LIB->_copy( $self->{_n} ), $self->{_d} );
            unless ( $LIB->_is_one($gcd) ) {
                $self->{_n} = $LIB->_div( $self->{_n}, $gcd );
                $self->{_d} = $LIB->_div( $self->{_d}, $gcd );
            }
        }

        $self->_dng() if $self->is_int();
        return $self;
    }

    return $self->bnan(@r);
}

sub from_bytes {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('from_bytes');

    my $str = shift;
    my @r   = @_;

    $self = $class->bzero(@r) unless $selfref;

    $self->{sign} = "+";
    $self->{_n}   = $LIB->_from_bytes($str);
    $self->{_d}   = $LIB->_one();

    $self->_dng();
    return $self;
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

    my $tmp = Math::BigFloat->from_ieee754( $in, $format, @r );

    $tmp = $tmp->as_rat();

    $self         = $class->bzero(@r) unless $selfref;
    $self->{sign} = $tmp->{sign};
    $self->{_n}   = $tmp->{_n};
    $self->{_d}   = $tmp->{_d};

    $self->_dng() if $self->is_int();
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
    $self->{_n} =
      $LIB->_from_base( $str, $base->{_n}, defined($cs) ? $cs : () );
    $self->{_d} = $LIB->_one();
    $self->bnorm();

    $self->_dng();
    return $self;
}

sub bzero {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('bzero');

    my $dng = $class->downgrade();
    if ( $dng && $dng ne $class ) {
        return $self->_dng()->bzero(@_) if $selfref;
        return $dng->bzero(@_);
    }

    my @r = @_;

    $self = bless {}, $class unless $selfref;

    $self->{sign} = '+';
    $self->{_n}   = $LIB->_zero();
    $self->{_d}   = $LIB->_one();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $r[0];
        $self->{precision} = $r[1];
    }
    else {
        unless ($selfref) {
            $self->{accuracy}  = $class->accuracy();
            $self->{precision} = $class->precision();
        }
    }

    return $self;
}

sub bone {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('bone');

    my $dng = $class->downgrade();
    if ( $dng && $dng ne $class ) {
        return $self->_dng()->bone(@_) if $selfref;
        return $dng->bone(@_);
    }

    my $sign = '+';
    if ( defined( $_[0] ) && $_[0] =~ /^\s*([+-])\s*$/ ) {
        $sign = $1;
        shift;
    }

    my @r = @_;

    $self = bless {}, $class unless $selfref;

    $self->{sign} = $sign;
    $self->{_n}   = $LIB->_one();
    $self->{_d}   = $LIB->_one();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $r[0];
        $self->{precision} = $r[1];
    }
    else {
        unless ($selfref) {
            $self->{accuracy}  = $class->accuracy();
            $self->{precision} = $class->precision();
        }
    }

    return $self;
}

sub binf {
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

    my $dng = $class->downgrade();
    if ( $dng && $dng ne $class ) {
        return $self->_dng()->binf( $sign, @r ) if $selfref;
        return $dng->binf( $sign, @r );
    }

    $self = bless {}, $class unless $selfref;

    $self->{sign} = $sign . 'inf';
    $self->{_n}   = $LIB->_zero();
    $self->{_d}   = $LIB->_one();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $r[0];
        $self->{precision} = $r[1];
    }
    else {
        unless ($selfref) {
            $self->{accuracy}  = $class->accuracy();
            $self->{precision} = $class->precision();
        }
    }

    return $self;
}

sub bnan {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    {
        no strict 'refs';
        if ( ${"${class}::_trap_nan"} ) {
            croak("Tried to create NaN in $class->bnan()");
        }
    }

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('bnan');

    my $dng = $class->downgrade();
    if ( $dng && $dng ne $class ) {
        return $self->_dng()->bnan(@_) if $selfref;
        return $dng->bnan(@_);
    }

    my @r = @_;

    $self = bless {}, $class unless $selfref;

    $self->{sign} = $nan;
    $self->{_n}   = $LIB->_zero();
    $self->{_d}   = $LIB->_one();

    if (@r) {
        if ( @r >= 2 && defined( $r[0] ) && defined( $r[1] ) ) {
            carp "can't specify both accuracy and precision";
            return $self->bnan();
        }
        $self->{accuracy}  = $r[0];
        $self->{precision} = $r[1];
    }
    else {
        unless ($selfref) {
            $self->{accuracy}  = $class->accuracy();
            $self->{precision} = $class->precision();
        }
    }

    return $self;
}

sub bpi {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;
    my @r       = @_;

    $class->import() if $IMPORT == 0;

    return $self if $selfref && $self->modify('bpi');

    $self = bless {}, $class unless $selfref;

    ( $self, @r ) = $self->_find_round_parameters(@r);

    my $n =
        defined $r[0] ? $r[0]
      : defined $r[1] ? 1 - $r[1]
      :                 $self->div_scale();

    my $max_iter = $n * 2.4;

    my $x = Math::BigFloat->bpi( $n + 10 );

    my $tol = $class->new("1/10")->bpow("$n")->bmul($x);

    my $n0 = $class->bzero();
    my $d0 = $class->bone();

    my $n1 = $class->bone();
    my $d1 = $class->bzero();

    my ( $n2, $d2 );

    my $xtmp = $x->copy();

    for ( my $iter = 0 ; $iter <= $max_iter ; $iter++ ) {
        my $t = $xtmp->copy()->bint();

        $n2 = $n1->copy()->bmul($t)->badd($n0);
        $d2 = $d1->copy()->bmul($t)->badd($d0);

        my $err = $n2->copy()->bdiv($d2)->bsub($x);
        last if $err->copy()->babs()->ble($tol);

        $xtmp->bsub($t);
        last if $xtmp->is_zero();
        $xtmp->binv();

        ( $n1, $n0 ) = ( $n2, $n1 );
        ( $d1, $d0 ) = ( $d2, $d1 );
    }

    my $mbr = $n2->bdiv($d2);
    %$self = %$mbr;
    return $self;
}

sub copy {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $self = shift() unless $selfref;

    my $copy = bless {}, $class;

    $copy->{sign}      = $self->{sign};
    $copy->{_d}        = $LIB->_copy( $self->{_d} );
    $copy->{_n}        = $LIB->_copy( $self->{_n} );
    $copy->{accuracy}  = $self->{accuracy}  if defined $self->{accuracy};
    $copy->{precision} = $self->{precision} if defined $self->{precision};

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
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return 1 if $x->{sign} eq '+' && $LIB->_is_zero( $x->{_n} );
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
    return 1 if $LIB->_is_one( $x->{_n} ) && $LIB->_is_one( $x->{_d} );
    return 0;
}

sub is_odd {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return 0 unless $x->is_finite();
    return 1 if $LIB->_is_one( $x->{_d} ) && $LIB->_is_odd( $x->{_n} );
    return 0;
}

sub is_even {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return 0 unless $x->is_finite();
    return 1 if $LIB->_is_one( $x->{_d} ) && $LIB->_is_even( $x->{_n} );
    return 0;
}

sub is_int {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return 1 if $x->is_finite() && $LIB->_is_one( $x->{_d} );
    return 0;
}

sub config {
    my $self  = shift;
    my $class = ref($self) || $self || __PACKAGE__;

    if ( @_ == 1 && ref( $_[0] ) ne 'HASH' ) {
        my $param = shift;
        return $class if $param eq 'class';
        return $LIB   if $param eq 'with';
        return $self->SUPER::config($param);
    }

    my $cfg = $self->SUPER::config(@_);

    unless ( ref($self) ) {
        $cfg->{class} = $class;
        $cfg->{with}  = $LIB;
    }

    $cfg;
}

sub bcmp {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( !$x->is_finite() || !$y->is_finite() ) {
        return if $x->is_nan() || $y->is_nan();
        return 0 if $x->{sign} eq $y->{sign} && $x->is_inf();
        return +1 if $x->is_inf("+");
        return -1 if $x->is_inf("-");
        return -1 if $y->is_inf("+");
        return +1;
    }

    return 1 if $x->{sign} eq '+' && $y->{sign} eq '-';
    return -1 if $x->{sign} eq '-' && $y->{sign} eq '+';

    my $xz = $LIB->_is_zero( $x->{_n} );
    my $yz = $LIB->_is_zero( $y->{_n} );
    return 0  if $xz && $yz;
    return -1 if $xz && $y->{sign} eq '+';
    return 1  if $yz && $x->{sign} eq '+';

    my $t = $LIB->_mul( $LIB->_copy( $x->{_n} ), $y->{_d} );
    my $u = $LIB->_mul( $LIB->_copy( $y->{_n} ), $x->{_d} );

    my $cmp = $LIB->_acmp( $t, $u );
    $cmp = -$cmp if $x->{sign} eq '-';
    $cmp;
}

sub bacmp {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( !$x->is_finite() || !$y->is_finite() ) {
        return   if ( $x->is_nan() || $y->is_nan() );
        return 0 if $x->is_inf() && $y->is_inf();
        return 1 if $x->is_inf() && !$y->is_inf();
        return -1;
    }

    my $t = $LIB->_mul( $LIB->_copy( $x->{_n} ), $y->{_d} );
    my $u = $LIB->_mul( $LIB->_copy( $y->{_n} ), $x->{_d} );
    $LIB->_acmp( $t, $u );
}

sub bneg {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bneg');

    $x->{sign} =~ tr/+-/-+/
      unless ( $x->{sign} eq '+' && $LIB->_is_zero( $x->{_n} ) );

    $x->round(@r);
    $x->_dng() if $x->is_int() || $x->is_inf() || $x->is_nan();
    return $x;
}

sub bnorm {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    if ( my $c = $LIB->_check( $x->{_n} ) ) {
        croak("n did not pass the self-check ($c) in bnorm()");
    }
    if ( my $c = $LIB->_check( $x->{_d} ) ) {
        croak("d did not pass the self-check ($c) in bnorm()");
    }

    if ( !$x->is_finite() ) {
        $x->_dng();
        return $x;
    }

    if ( $LIB->_is_zero( $x->{_n} ) ) {
        $x->{sign} = '+';
        $x->{_d}   = $LIB->_one() unless $LIB->_is_one( $x->{_d} );
        $x->_dng();
        return $x;
    }

    if ( $LIB->_is_one( $x->{_d} ) ) {
        $x->_dng();
        return $x;
    }

    my $gcd = $LIB->_gcd( $LIB->_copy( $x->{_n} ), $x->{_d} );
    if ( !$LIB->_is_one($gcd) ) {
        $x->{_n} = $LIB->_div( $x->{_n}, $gcd );
        $x->{_d} = $LIB->_div( $x->{_d}, $gcd );
    }

    $x;
}

sub binc {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('binc');

    if ( !$x->is_finite() ) {
        $x->round(@r);
        $x->_dng();
        return $x;
    }

    if ( $x->{sign} eq '-' ) {
        if ( $LIB->_acmp( $x->{_n}, $x->{_d} ) < 0 ) {
            $x->{_n}   = $LIB->_sub( $LIB->_copy( $x->{_d} ), $x->{_n} );
            $x->{sign} = '+';
        }
        else {
            $x->{_n} = $LIB->_sub( $x->{_n}, $x->{_d} );
        }
    }
    else {
        $x->{_n} = $LIB->_add( $x->{_n}, $x->{_d} );
    }

    $x->bnorm();
    $x->round(@r);
    $x->_dng() if $x->is_int() || $x->is_inf() || $x->is_nan();
    return $x;
}

sub bdec {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bdec');

    if ( !$x->is_finite() ) {
        $x->round(@r);
        $x->_dng();
        return $x;
    }

    if ( $x->{sign} eq '-' ) {
        $x->{_n} = $LIB->_add( $x->{_n}, $x->{_d} );
    }
    else {
        if ( $LIB->_acmp( $x->{_n}, $x->{_d} ) < 0 ) {
            $x->{_n}   = $LIB->_sub( $LIB->_copy( $x->{_d} ), $x->{_n} );
            $x->{sign} = '-';
        }
        else {
            $x->{_n} = $LIB->_sub( $x->{_n}, $x->{_d} );
        }
    }

    $x->bnorm();
    $x->round(@r);
    $x->_dng() if $x->is_int() || $x->is_inf() || $x->is_nan();
    return $x;
}

sub badd {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('badd');

    unless ( $x->is_finite() && $y->is_finite() ) {
        if ( $x->is_nan() || $y->is_nan() ) {
            return $x->bnan(@r);
        }
        elsif ( $x->is_inf("+") ) {
            return $x->bnan(@r) if $y->is_inf("-");
            return $x->binf( "+", @r );
        }
        elsif ( $x->is_inf("-") ) {
            return $x->bnan(@r) if $y->is_inf("+");
            return $x->binf( "-", @r );
        }
        elsif ( $y->is_inf("+") ) {
            return $x->binf( "+", @r );
        }
        elsif ( $y->is_inf("-") ) {
            return $x->binf( "-", @r );
        }
    }

    $x->{_n} = $LIB->_mul( $x->{_n}, $y->{_d} );

    my $m = $LIB->_mul( $LIB->_copy( $y->{_n} ), $x->{_d} );

    ( $x->{_n}, $x->{sign} ) =
      $LIB->_sadd( $x->{_n}, $x->{sign}, $m, $y->{sign} );

    $x->{_d} = $LIB->_mul( $x->{_d}, $y->{_d} );

    $x->bnorm()->round(@r);
}

sub bsub {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bsub');

    $x->{sign} =~ tr/+-/-+/
      unless $x->{sign} eq '+' && $x->is_zero();
    $x = $x->badd( $y, @r );
    $x->{sign} =~ tr/+-/-+/
      unless $x->{sign} eq '+' && $x->is_zero();

    $x->bnorm();
}

sub bmul {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bmul');

    return $x->bnan(@r) if $x->is_nan() || $y->is_nan();

    if ( $x->is_inf() || $y->is_inf() ) {
        return $x->bnan(@r) if $x->is_zero() || $y->is_zero();
        return $x->binf(@r) if $x->is_positive() && $y->is_positive();
        return $x->binf(@r) if $x->is_negative() && $y->is_negative();
        return $x->binf( '-', @r );
    }

    return $x->_upg()->bmul( $y, @r ) if $class->upgrade();

    if ( $x->is_zero() || $y->is_zero() ) {
        return $x->bzero(@r);
    }

    my $gcd_pr = $LIB->_gcd( $LIB->_copy( $x->{_n} ), $y->{_d} );
    my $gcd_sq = $LIB->_gcd( $LIB->_copy( $y->{_n} ), $x->{_d} );

    $x->{_n} = $LIB->_mul( scalar $LIB->_div( $x->{_n}, $gcd_pr ),
        scalar $LIB->_div( $LIB->_copy( $y->{_n} ), $gcd_sq ) );
    $x->{_d} = $LIB->_mul( scalar $LIB->_div( $x->{_d}, $gcd_sq ),
        scalar $LIB->_div( $LIB->_copy( $y->{_d} ), $gcd_pr ) );

    $x->{sign} = $x->{sign} eq $y->{sign} ? '+' : '-';

    $x->bnorm();
    $x->round(@r);
    $x->_dng() if $x->is_int();
    return $x;
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
            $rem->_dng() if $rem->is_int();
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
        if ($wantarray) {
            if ( $x->is_zero() || $x->bcmp(0) == $y->bcmp(0) ) {
                $rem = $x->copy()->round(@r);
                $rem->_dng() if $rem->is_int();
                $x->bzero(@r);
            }
            else {
                $rem = $class->binf( $y->{sign}, @r );
                $x->bone( '-', @r );
            }
        }
        else {
            $x->bzero(@r);
        }
        return $wantarray ? ( $x, $rem ) : $x;
    }

    $x->{_n} = $LIB->_mul( $x->{_n}, $y->{_d} );
    $x->{_d} = $LIB->_mul( $x->{_d}, $y->{_n} );

    $x->{sign} = $x->{sign} eq $y->{sign} ? '+' : '-';

    $x->bnorm();
    if ($wantarray) {
        my $rem = $x->copy();
        $x->bfloor();
        $x->round(@r);
        $rem->bsub( $x->copy() )->bmul($y);
        $x->_dng()   if $x->is_int();
        $rem->_dng() if $rem->is_int();
        return $x, $rem;
    }

    $x->_dng() if $x->is_int();
    return $x;
}

sub bfmod {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bfmod');

    if ( $x->is_nan() || $y->is_nan() ) {
        return $x->bnan();
    }

    if ( $y->is_zero() ) {
        return $x->round();
    }

    if ( $x->is_inf() ) {
        return $x->bnan();
    }

    if ( $y->is_inf() ) {
        if ( $x->is_zero() || $x->bcmp(0) == $y->bcmp(0) ) {
            $x->_dng() if $x->is_int();
            return $x;
        }
        else {
            return $x->binf( $y->sign() );
        }
    }

    if ( $x->is_zero() ) {
        return $x->bzero();
    }

    $x->bsub( $x->copy()->bfdiv($y)->bfloor()->bmul($y) );
    return $x->round(@r);
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
            $rem = $x->copy()->round(@r);
            $rem->_dng() if $rem->is_int();
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
        if ($wantarray) {
            $rem = $x->copy();
            $rem->_dng() if $rem->is_int();
            $x->bzero();
            return $x, $rem;
        }
        else {
            if ( $y->is_inf() ) {
                if ( $x->is_nan() || $x->is_inf() ) {
                    return $x->bnan();
                }
                else {
                    return $x->bzero();
                }
            }
        }
    }

    if ( $x->is_zero() ) {
        $x->round(@r);
        $x->_dng() if $x->is_int();
        if ($wantarray) {
            my $rem = $class->bzero(@r);
            return $x, $rem;
        }
        return $x;
    }

    $x->{_n} = $LIB->_mul( $x->{_n}, $y->{_d} );
    $x->{_d} = $LIB->_mul( $x->{_d}, $y->{_n} );

    $x->{sign} = $x->{sign} eq $y->{sign} ? '+' : '-';

    $x->bnorm();
    if ($wantarray) {
        my $rem = $x->copy();
        $x->bint();
        $x->round(@r);
        $rem->bsub( $x->copy() )->bmul($y);
        $x->_dng()   if $x->is_int();
        $rem->_dng() if $rem->is_int();
        return $x, $rem;
    }

    $x->_dng() if $x->is_int();
    return $x;
}

sub btmod {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('btmod');

    if ( $x->is_nan() || $y->is_nan() ) {
        return $x->bnan();
    }

    if ( $y->is_zero() ) {
        return $x->round();
    }

    if ( $x->is_inf() ) {
        return $x->bnan();
    }

    if ( $y->is_inf() ) {
        $x->_dng() if $x->is_int();
        return $x;
    }

    if ( $x->is_zero() ) {
        return $x->bzero();
    }

    my $p = $x->{_n};
    my $q = $x->{_d};
    my $r = $y->{_n};
    my $s = $y->{_d};

    my $gcd_qs      = $LIB->_gcd( $LIB->_copy($q), $s );
    my $s_by_gcd_qs = $LIB->_div( $LIB->_copy($s), $gcd_qs );
    my $q_by_gcd_qs = $LIB->_div( $LIB->_copy($q), $gcd_qs );

    my $u = $LIB->_mul( $LIB->_copy($p), $s_by_gcd_qs );
    my $v = $LIB->_mul( $LIB->_copy($r), $q_by_gcd_qs );
    my $w = $LIB->_mul( $LIB->_copy($q), $s_by_gcd_qs );

    $x->{_n} = $LIB->_mod( $u, $v );
    $x->{_d} = $w;

    $x->bnorm();
    return $x->round(@r);
}

sub binv {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    return $x if $x->modify('binv');

    return $x->round(@r)       if $x->is_nan();
    return $x->bzero(@r)       if $x->is_inf();
    return $x->binf( "+", @r ) if $x->is_zero();

    ( $x->{_n}, $x->{_d} ) = ( $x->{_d}, $x->{_n} );

    $x->round(@r);
    $x->_dng() if $x->is_int() || $x->is_inf() || $x->is_nan();
    return $x;
}

sub bsqrt {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bsqrt');

    return $x->bnan()    if $x->{sign} !~ /^[+]/;
    return $x            if $x->is_inf("+");
    return $x->round(@r) if $x->is_zero() || $x->is_one();

    my $n = $x->{_n};
    my $d = $x->{_d};

    {
        my $nsqrt = $LIB->_sqrt( $LIB->_copy($n) );
        my $n2    = $LIB->_mul( $LIB->_copy($nsqrt), $nsqrt );
        if ( $LIB->_acmp( $n, $n2 ) == 0 ) {
            my $dsqrt = $LIB->_sqrt( $LIB->_copy($d) );
            my $d2    = $LIB->_mul( $LIB->_copy($dsqrt), $dsqrt );
            if ( $LIB->_acmp( $d, $d2 ) == 0 ) {
                $x->{_n} = $nsqrt;
                $x->{_d} = $dsqrt;
                return $x->round(@r);
            }
        }
    }

    local $Math::BigFloat::upgrade   = undef;
    local $Math::BigFloat::downgrade = undef;
    local $Math::BigFloat::precision = undef;
    local $Math::BigFloat::accuracy  = undef;
    local $Math::BigInt::upgrade     = undef;
    local $Math::BigInt::precision   = undef;
    local $Math::BigInt::accuracy    = undef;

    my $xn = Math::BigFloat->new( $LIB->_str($n) );
    my $xd = Math::BigFloat->new( $LIB->_str($d) );

    my $xtmp = Math::BigRat->new( $xn->bfdiv($xd)->bsqrt()->bfstr() );

    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};

    $x->round(@r);
}

sub bpow {

    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bpow');

    return $x->bnan() if $x->is_nan() || $y->is_nan();

    if ( $x->is_inf("-") ) {
        return $x->bzero() if $y->is_negative();
        return $x->bnan()  if $y->is_zero();
        return $x          if $y->is_odd();
        return $x->bneg();
    }
    elsif ( $x->is_inf("+") ) {
        return $x->bzero() if $y->is_negative();
        return $x->bnan()  if $y->is_zero();
        return $x;
    }
    elsif ( $y->is_inf("-") ) {
        return $x->bnan()    if $x->is_one("-");
        return $x->binf("+") if $x > -1 && $x < 1;
        return $x->bone()    if $x->is_one("+");
        return $x->bzero();
    }
    elsif ( $y->is_inf("+") ) {
        return $x->bnan()  if $x->is_one("-");
        return $x->bzero() if $x > -1 && $x < 1;
        return $x->bone()  if $x->is_one("+");
        return $x->binf("+");
    }

    if ( $x->is_zero() ) {
        return $x->bone() if $y->is_zero();
        return $x->binf() if $y->is_negative();
        return $x;
    }

    if ( $x->is_negative() && !$y->is_int() ) {
        return $x->_upg()->bpow( $y, @r ) if $class->upgrade();
        return $x->bnan();
    }

    if ( $x->is_one("+") || $y->is_one() ) {
        return $x;
    }

    if ( $x->is_one("-") ) {
        return $x if $y->is_odd();
        return $x->bneg();
    }

    ( $x->{_n}, $x->{_d} ) = ( $x->{_d}, $x->{_n} ) if $y->is_negative();

    unless ( $LIB->_is_one( $y->{_n} ) ) {
        $x->{_n}   = $LIB->_pow( $x->{_n}, $y->{_n} );
        $x->{_d}   = $LIB->_pow( $x->{_d}, $y->{_n} );
        $x->{sign} = '+' if $x->{sign} eq '-' && $LIB->_is_even( $y->{_n} );
    }

    unless ( $LIB->_is_one( $y->{_d} ) ) {
        return $x->bsqrt(@r) if $LIB->_is_two( $y->{_d} );
        return $x->broot( $LIB->_str( $y->{_d} ), @r );
    }

    return $x->round(@r);
}

sub broot {
    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('broot');

    my $xd   = Math::BigFloat->new( $LIB->_str( $x->{_d} ) );
    my $xflt = Math::BigFloat->new( $LIB->_str( $x->{_n} ) )->bfdiv($xd);
    $xflt->{sign} = $x->{sign};

    my $yd   = Math::BigFloat->new( $LIB->_str( $y->{_d} ) );
    my $yflt = Math::BigFloat->new( $LIB->_str( $y->{_n} ) )->bfdiv($yd);
    $yflt->{sign} = $y->{sign};

    $xflt->broot( $yflt, @r );
    my $xtmp = Math::BigRat->new( $xflt->bfstr() );

    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};

    return $x;
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
            if ( $z->is_inf("+") ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "-", @r );
            }
        }

    }
    elsif ( $x->is_inf("+") ) {

        if ( $y->is_neg() ) {
            if ( $z->is_inf("+") ) {
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
        elsif ( $y->is_inf("+") ) {
            if ( $z->is_inf("+") ) {
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
            elsif ( $z->is_inf("+") ) {
                return $x->binf( "+", @r );
            }
        }

    }
    elsif ( $x->is_zero() ) {

        if ( $y->is_inf("-") ) {
            return $x->bnan(@r);
        }
        elsif ( $y->is_inf("+") ) {
            return $x->bnan(@r);
        }
        else {
            if ( $z->is_inf("-") ) {
                return $x->binf( "-", @r );
            }
            elsif ( $z->is_inf("+") ) {
                return $x->binf( "+", @r );
            }
        }

    }
    elsif ( $x->is_pos() ) {

        if ( $y->is_inf("-") ) {
            if ( $z->is_inf("+") ) {
                return $x->bnan(@r);
            }
            else {
                return $x->binf( "-", @r );
            }
        }
        elsif ( $y->is_inf("+") ) {
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
            elsif ( $z->is_inf("+") ) {
                return $x->binf( "+", @r );
            }
        }
    }

    my $xn_yn    = $LIB->_mul( $LIB->_copy( $x->{_n} ), $y->{_n} );
    my $xn_yn_zd = $LIB->_mul( $xn_yn,                  $z->{_d} );

    my $xd_yd    = $LIB->_mul( $x->{_d},            $y->{_d} );
    my $xd_yd_zn = $LIB->_mul( $LIB->_copy($xd_yd), $z->{_n} );

    my $xd_yd_zd = $LIB->_mul( $xd_yd, $z->{_d} );

    my $sgn1 = $x->{sign} eq $y->{sign} ? "+" : "-";
    my $sgn2 = $z->{sign};

    ( $x->{_n}, $x->{sign} ) =
      $LIB->_sadd( $xn_yn_zd, $sgn1, $xd_yd_zn, $sgn2 );
    $x->{_d} = $xd_yd_zd;
    $x->bnorm();

    return $x;
}

sub bmodpow {
    my ( $class, $x, $y, $m, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      && ref( $_[1] ) eq ref( $_[2] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 3, @_ );

    return $x if $x->modify('bmodpow');

    my $xint = Math::BigInt->new( $x->copy()->bint() );
    my $yint = Math::BigInt->new( $y->copy()->bint() );
    my $mint = Math::BigInt->new( $m->copy()->bint() );

    $xint->bmodpow( $yint, $mint, @r );
    my $xtmp = Math::BigRat->new( $xint->bfstr() );

    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};
    return $x;
}

sub bmodinv {
    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bmodinv');

    my $xint = Math::BigInt->new( $x->copy()->bint() );
    my $yint = Math::BigInt->new( $y->copy()->bint() );

    $xint->bmodinv( $yint, @r );
    my $xtmp = Math::BigRat->new( $xint->bfstr() );

    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};
    return $x;
}

sub blog {

    my ( $class, $x, $base, @r );

    if ( !ref( $_[0] ) && $_[0] =~ /^[A-Za-z]|::/ ) {
        ( $class, $x, $base, @r ) =
          defined $_[2] ? objectify( 2, @_ ) : objectify( 1, @_ );
    }
    else {
        ( $class, $x, $base, @r ) =
          defined $_[1] ? objectify( 2, @_ ) : objectify( 1, @_ );
    }

    return $x if $x->modify('blog');

    return $x->bnan() if $x->is_nan();

    if ( defined $base ) {
        $base = $class->new($base) unless ref $base;
        if ( $base->is_nan() || $base->is_one() ) {
            return $x->bnan();
        }
        elsif ( $base->is_inf() || $base->is_zero() ) {
            return $x->bnan() if $x->is_inf() || $x->is_zero();
            return $x->bzero();
        }
        elsif ( $base->is_negative() ) {
            return $x->bzero() if $x->is_one();
            return $x->bone()  if $x == $base;
            return $x->bnan();
        }
        return $x->bone() if $x == $base;
    }

    if ( $x->is_inf() ) {
        my $sign = defined $base && $base < 1 ? '-' : '+';
        return $x->binf($sign);
    }
    elsif ( $x->is_neg() ) {
        return $x->bnan();
    }
    elsif ( $x->is_one() ) {
        return $x->bzero();
    }
    elsif ( $x->is_zero() ) {
        my $sign = defined $base && $base < 1 ? '+' : '-';
        return $x->binf($sign);
    }

    my $neg = 0;
    if ( $x->numerator()->is_one() ) {
        $x->binv();
        $neg = !$neg;
    }
    if ( defined( blessed($base) ) && $base->isa($class) ) {
        if ( $base->numerator()->is_one() ) {
            $base = $base->copy()->binv();
            $neg  = !$neg;
        }
    }

    require Math::BigFloat;
    my $upg = Math::BigFloat->upgrade();
    my $dng = Math::BigFloat->downgrade();
    Math::BigFloat->upgrade(undef);
    Math::BigFloat->downgrade(undef);

    $base = Math::BigFloat->new($base) if defined $base;
    my $xnum = Math::BigFloat->new( $LIB->_str( $x->{_n} ) );
    my $xden = Math::BigFloat->new( $LIB->_str( $x->{_d} ) );
    my $xstr = $xnum->bfdiv($xden)->blog( $base, @r )->bfstr();

    Math::BigFloat->upgrade($upg);
    Math::BigFloat->downgrade($dng);

    my $xobj = Math::BigRat->new($xstr);
    $x->{sign} = $xobj->{sign};
    $x->{_n}   = $xobj->{_n};
    $x->{_d}   = $xobj->{_d};

    return $neg ? $x->bneg() : $x;
}

sub bexp {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bexp');

    return $x->binf(@r)  if $x->is_inf("+");
    return $x->bzero(@r) if $x->is_inf("-");

    my $fallback = 0;
    my ( $scale, @params );
    ( $x, @params ) = $x->_find_round_parameters(@r);

    return $x if $x->is_nan();

    if ( scalar @params == 0 ) {
        $params[0] = $class->div_scale();
        $params[1] = undef;
        $scale     = $params[0] + 4;
        $params[2] = $r[2];
        $fallback  = 1;
    }
    else {
        $scale = abs( $params[0] || $params[1] ) + 4;
    }

    return $x->bone(@params) if $x->is_zero();

    my $x_org = $x->copy();
    if ( $scale <= 75 ) {
        $x->{_n} =
          $LIB->_new("90933395208605785401971970164779391644753259799242");
        $x->{_d} =
          $LIB->_new("33452526613163807108170062053440751665152000000000");
        $x->{sign} = '+';
    }
    else {

        my $A =
          $LIB->_new("90933395208605785401971970164779391644753259799242");
        my $F    = $LIB->_new(42);
        my $step = 42;

        my $steps = Math::BigFloat::_len_to_steps( $scale - 4 );
        while ( $step++ <= $steps ) {
            $A = $LIB->_mul( $A, $F );
            $A = $LIB->_inc($A);
            $F = $LIB->_inc($F);
        }
        my $B = $LIB->_fac( $LIB->_new($steps) );

        $x->{_n}   = $A;
        $x->{_d}   = $B;
        $x->{sign} = '+';
    }

    if ( !$x_org->is_one() ) {
        $x->bpow( $x_org, @params );
    }
    else {
        delete $x->{accuracy};
        delete $x->{precision};
        if ( defined $params[0] ) {
            $x->bround( $params[0], $params[2] );
        }
        else {
            $x->bfround( $params[1], $params[2] );
        }
    }
    if ($fallback) {
        delete $x->{accuracy};
        delete $x->{precision};
    }

    $x;
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

    $x->{_n} = $LIB->_div( $x->{_n}, $x->{_d} );
    $x->{_n} = $LIB->_ilog2( $x->{_n} );
    $x->{_d} = $LIB->_one();
    $x->bnorm()->round(@r);
    $x->_dng();
    return $x;
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

    $x->{_n} = $LIB->_div( $x->{_n}, $x->{_d} );
    $x->{_n} = $LIB->_ilog10( $x->{_n} );
    $x->{_d} = $LIB->_one();
    $x->bnorm()->round(@r);
    $x->_dng();
    return $x;
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

    $x->{_n} = $LIB->_div( $x->{_n}, $x->{_d} );
    $x->{_n} = $LIB->_clog2( $x->{_n} );
    $x->{_d} = $LIB->_one();
    $x->bnorm()->round(@r);
    $x->_dng();
    return $x;
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

    $x->{_n} = $LIB->_div( $x->{_n}, $x->{_d} );
    $x->{_n} = $LIB->_clog10( $x->{_n} );
    $x->{_d} = $LIB->_one();
    $x->bnorm()->round(@r);
    $x->_dng();
    return $x;
}

sub bnok {
    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x if $x->modify('bnok');

    return $x->bnan() if $x->is_nan() || $y->is_nan();
    return $x->bnan()
      if ( ( $x->is_finite() && !$x->is_int() )
        || ( $y->is_finite() && !$y->is_int() ) );

    my $xint = Math::BigInt->new( $x->bstr() );
    my $yint = Math::BigInt->new( $y->bstr() );
    $xint->bnok($yint);
    my $xrat = Math::BigRat->new($xint);

    $x->{sign} = $xrat->{sign};
    $x->{_n}   = $xrat->{_n};
    $x->{_d}   = $xrat->{_d};

    return $x;
}

sub bperm {
    my ( $class, $x, $y, @r ) =
      ref( $_[0] ) && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x if $x->modify('bperm');

    return $x->bnan() if $x->is_nan() || $y->is_nan();
    return $x->bnan()
      if ( ( $x->is_finite() && !$x->is_int() )
        || ( $y->is_finite() && !$y->is_int() ) );

    my $xint = Math::BigInt->new( $x->bstr() );
    my $yint = Math::BigInt->new( $y->bstr() );
    $xint->bperm($yint);
    my $xrat = Math::BigRat->new($xint);

    $x->{sign} = $xrat->{sign};
    $x->{_n}   = $xrat->{_n};
    $x->{_d}   = $xrat->{_d};

    return $x;
}

sub bfac {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bfac');

    return $x->bnan(@r)        if $x->is_nan() || $x->is_inf("-");
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->bnan(@r)        if $x->is_neg()  || !$x->is_int();
    return $x->bone(@r)        if $x->is_zero() || $x->is_one();

    $x->{_n} = $LIB->_fac( $x->{_n} );
    $x->round(@r);
    $x->_dng();
    return $x;
}

sub bdfac {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bdfac');

    return $x->bnan(@r)        if $x->is_nan() || $x->is_inf("-");
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->bnan(@r)        if $x <= -2 || !$x->is_int();
    return $x->bone(@r)        if $x <= 1;

    croak("bdfac() requires a newer version of the $LIB library.")
      unless $LIB->can('_dfac');

    $x->{_n} = $LIB->_dfac( $x->{_n} );
    $x->round(@r);
    $x->_dng();
    return $x;
}

sub btfac {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('btfac');

    return $x->bnan(@r)        if $x->is_nan() || !$x->is_int();
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
    $x->_dng();
    return $x;
}

sub bmfac {

    my ( $class, $x, $k, @r ) =
         ref( $_[0] )
      && ref( $_[0] ) eq ref( $_[1] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 2, @_ );

    return $x if $x->modify('bmfac');

    return $x->bnan(@r)
      if $x->is_nan()
      || $x->is_inf("-")
      || !$k->is_pos();
    return $x->binf( "+", @r ) if $x->is_inf("+");
    return $x->bround(@r)      if $k->is_inf("+");
    return $x->bnan(@r)        if !$x->is_int() || !$k->is_int();
    return $x->bnan(@r)        if $k < 1        || $x <= -$k;

    my $one = $class->bone();
    return $x->bone(@r) if $x <= $one;

    my $f = $x->copy();
    while ( $f->bsub($k) > $one ) {
        $x->bmul($f);
    }
    $x->round(@r);
    $x->_dng();
    return $x;
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
            $y[0]     = $x->copy()->babs();
            $y[0]{_n} = $LIB->_zero();
            $y[0]{_d} = $LIB->_one();
            last if $n == 0;

            $y[1]     = $y[0]->copy();
            $y[1]{_n} = $LIB->_one();
            $y[1]{_d} = $LIB->_one();
            last if $n == 1;

            for ( my $i = 2 ; $i <= abs($n) ; $i++ ) {
                $y[$i] = $y[ $i - 1 ]->copy();
                $y[$i]{_n} = $LIB->_add( $LIB->_copy( $y[ $i - 1 ]{_n} ),
                    $y[ $i - 2 ]{_n} );
            }

            if ( $x->is_neg() ) {
                for ( my $i = 2 ; $i <= $#y ; $i += 2 ) {
                    $y[$i]{sign} = '-';
                }
            }

            $x->{sign} = $y[-1]{sign};
            $x->{_n}   = $y[-1]{_n};
            $x->{_d}   = $y[-1]{_d};
            $y[-1]     = $x;
        }

        for (@y) {
            $_->bnorm();
            $_->round(@r);
        }

        return @y;
    }

    else {
        return $x if $x->is_inf('+');
        return $x->bnan()
          if $x->is_nan()
          || $x->is_inf('-')
          || !$x->is_int();

        $x->{sign} = $x->is_neg() && $x->is_even() ? '-' : '+';
        $x->{_n}   = $LIB->_fib( $x->{_n} );
        $x->{_d}   = $LIB->_one();
        $x->bnorm();
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
        croak("blucas() can't return an infinitely long list of numbers")
          if $x->is_inf();

        return if $x->is_nan() || !$x->is_int();

        my $n = $x->numify();

        my @y;
        {
            $y[0] = $x->copy()->babs();
            $y[0]{_n} = $LIB->_two();
            last if $n == 0;

            $y[1] = $y[0]->copy();
            $y[1]{_n} = $LIB->_one();
            last if $n == 1;

            for ( my $i = 2 ; $i <= abs($n) ; $i++ ) {
                $y[$i] = $y[ $i - 1 ]->copy();
                $y[$i]{_n} = $LIB->_add( $LIB->_copy( $y[ $i - 1 ]{_n} ),
                    $y[ $i - 2 ]{_n} );
            }

            if ( $x->is_neg() ) {
                for ( my $i = 2 ; $i <= $#y ; $i += 2 ) {
                    $y[$i]{sign} = '-';
                }
            }

            $x->{_n}   = $y[-1]{_n};
            $x->{sign} = $y[-1]{sign};
            $y[-1]     = $x;
        }

        @y = map { $_->round(@r) } @y;
        return @y;
    }

    else {
        return $x if $x->is_inf('+');
        return $x->bnan()
          if $x->is_nan()
          || $x->is_inf('-')
          || !$x->is_int();

        $x->{sign} = $x->is_neg() && $x->is_even() ? '-' : '+';
        $x->{_n}   = $LIB->_lucas( $x->{_n} );
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

    $b = 2               unless defined($b);
    $b = $class->new($b) unless ref($b) && $b->isa($class);

    return $x->bnan() if $x->is_nan() || $y->is_nan() || $b->is_nan();

    return $x->brsft( $y->copy()->babs(), $b ) if $y->{sign} =~ /^-/;

    $x->bmul( $b->bpow($y) );
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

    $b = 2               unless defined($b);
    $b = $class->new($b) unless ref($b) && $b->isa($class);

    return $x->bnan() if $x->is_nan() || $y->is_nan() || $b->is_nan();

    return $x->blsft( $y->copy()->babs(), $b ) if $y->{sign} =~ /^-/;

    $x->bfdiv( $b->bpow($y) );
}

sub bblsft {

    my ( $class, $x, $y, @r ) = ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : @_;

    return $x if $x->modify('bblsft');

    my $xint = Math::BigInt->bblsft( $x, $y, @r );

    my $dng = $class->downgrade();
    $class->downgrade(undef);

    my $xrat = $class->new($xint);

    $class->downgrade($dng);

    if ( defined( blessed($x) ) && $x->isa(__PACKAGE__) ) {
        $x->{sign} = $xrat->{sign};
        $x->{_n}   = $xrat->{_n};
        $x->{_d}   = $xrat->{_d};
    }
    else {
        $x = $xrat;
    }

    $x->round(@r);
    $x->_dng();
    return $x;
}

sub bbrsft {

    my ( $class, $x, $y, @r ) = ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : @_;

    return $x if $x->modify('bbrsft');

    my $xint = Math::BigInt->bbrsft( $x, $y, @r );

    my $dng = $class->downgrade();
    $class->downgrade(undef);

    my $xrat = $class->new($xint);

    $class->downgrade($dng);

    if ( defined( blessed($x) ) && $x->isa(__PACKAGE__) ) {
        $x->{sign} = $xrat->{sign};
        $x->{_n}   = $xrat->{_n};
        $x->{_d}   = $xrat->{_d};
    }
    else {
        $x = $xrat;
    }

    $x->round(@r);
    $x->_dng();
    return $x;
}

sub band {
    my $x     = shift;
    my $xref  = ref($x);
    my $class = $xref || $x;

    return $x if $x->modify('band');

    croak 'band() is an instance method, not a class method' unless $xref;
    croak 'Not enough arguments for band()' if @_ < 1;

    my $y = shift;
    $y = $class->new($y) unless ref($y);

    my @r = @_;

    my $xtmp = $x->as_int()->band( $y->as_int() )->as_rat();
    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};

    return $x->round(@r);
}

sub bior {
    my $x     = shift;
    my $xref  = ref($x);
    my $class = $xref || $x;

    return $x if $x->modify('bior');

    croak 'bior() is an instance method, not a class method' unless $xref;
    croak 'Not enough arguments for bior()' if @_ < 1;

    my $y = shift;
    $y = $class->new($y) unless ref($y);

    my @r = @_;

    my $xtmp = $x->as_int()->bior( $y->as_int() )->as_rat();
    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};

    return $x->round(@r);
}

sub bxor {
    my $x     = shift;
    my $xref  = ref($x);
    my $class = $xref || $x;

    return $x if $x->modify('bxor');

    croak 'bxor() is an instance method, not a class method' unless $xref;
    croak 'Not enough arguments for bxor()' if @_ < 1;

    my $y = shift;
    $y = $class->new($y) unless ref($y);

    my @r = @_;

    my $xtmp = $x->as_int()->bxor( $y->as_int() )->as_rat();
    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};

    return $x->round(@r);
}

sub bnot {
    my $x     = shift;
    my $xref  = ref($x);
    my $class = $xref || $x;

    return $x if $x->modify('bnot');

    croak 'bnot() is an instance method, not a class method' unless $xref;

    my @r = @_;

    my $xtmp = $x->as_int()->bnot()->as_rat();
    $x->{sign} = $xtmp->{sign};
    $x->{_n}   = $xtmp->{_n};
    $x->{_d}   = $xtmp->{_d};

    return $x->round(@r);
}

sub round {
    my $x = shift;

    return $x if $x->modify('round');

    $x->_dng() if ( $x->is_int()
        || $x->is_inf()
        || $x->is_nan() );
    $x;
}

sub bround {
    my $x = shift;

    return $x if $x->modify('bround');

    $x->_dng() if ( $x->is_int()
        || $x->is_inf()
        || $x->is_nan() );
    $x;
}

sub bfround {
    my $x = shift;

    return $x if $x->modify('bfround');

    $x->_dng() if ( $x->is_int()
        || $x->is_inf()
        || $x->is_nan() );
    $x;
}

sub bfloor {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bfloor');

    return $x->bnan(@r) if $x->is_nan();

    if (  !$x->is_finite()
        || $LIB->_is_one( $x->{_d} ) )
    {
        $x->round(@r);
        $x->_dng();
        return $x;
    }

    $x->{_n} = $LIB->_div( $x->{_n}, $x->{_d} );
    $x->{_d} = $LIB->_one();
    $x->{_n} = $LIB->_inc( $x->{_n} ) if $x->{sign} eq '-';

    $x->round(@r);
    $x->_dng();
    return $x;
}

sub bceil {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bceil');

    return $x->bnan(@r) if $x->is_nan();

    if (  !$x->is_finite()
        || $LIB->_is_one( $x->{_d} ) )
    {
        $x->round(@r);
        $x->_dng();
        return $x;
    }

    $x->{_n}   = $LIB->_div( $x->{_n}, $x->{_d} );
    $x->{_d}   = $LIB->_one();
    $x->{_n}   = $LIB->_inc( $x->{_n} ) if $x->{sign} eq '+';
    $x->{sign} = '+' if $x->{sign} eq '-' && $LIB->_is_zero( $x->{_n} );

    $x->round(@r);
    $x->_dng();
    return $x;
}

sub bint {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    return $x if $x->modify('bint');

    return $x->bnan(@r) if $x->is_nan();

    if (  !$x->is_finite()
        || $LIB->_is_one( $x->{_d} ) )
    {
        $x->round(@r);
        $x->_dng();
        return $x;
    }

    $x->{_n}   = $LIB->_div( $x->{_n}, $x->{_d} );
    $x->{_d}   = $LIB->_one();
    $x->{sign} = '+' if $x->{sign} eq '-' && $LIB->_is_zero( $x->{_n} );

    $x->round(@r);
    $x->_dng();
    return $x;
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
        return $class->bnan() unless $arg->is_finite();
    }

    my $dng = $class->downgrade();
    $class->downgrade(undef);

    my $x = shift @args;
    $x = $x->copy();

    while (@args) {
        my $y = shift @args;

        while ( !$y->is_zero() ) {
            ( $x, $y ) = ( $y->copy(), $x->copy()->bmod($y) );
        }

        last if $x->is_one();
    }
    $x->babs();

    $class->downgrade($dng);

    $x->_dng() if $x->is_int();
    return $x;
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

    my $x = shift @args;
    $x = $x->copy();

    while (@args) {
        my $y   = shift @args;
        my $gcd = $x->copy()->bgcd($y);
        $x->bdiv($gcd)->bmul($y);
    }

    $x->babs();
    return $x;
}

sub digit {
    my ( $class, $x, $n ) =
      ref( $_[0] ) ? ( undef, $_[0], $_[1] ) : objectify( 1, @_ );

    return $nan unless $x->is_int();
    $LIB->_digit( $x->{_n}, $n || 0 );
}

sub length {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return $nan unless $x->is_int();
    $LIB->_len( $x->{_n} );
}

sub parts {
    my ( $class, $x ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    my $c = 'Math::BigInt';

    return ( $c->bnan(),    $c->bnan() ) if $x->is_nan();
    return ( $c->binf(),    $c->binf() ) if $x->is_inf("+");
    return ( $c->binf('-'), $c->binf() ) if $x->is_inf("-");

    my $n = $c->new( $LIB->_str( $x->{_n} ) );
    $n->{sign} = $x->{sign};
    my $d = $c->new( $LIB->_str( $x->{_d} ) );
    ( $n, $d );
}

sub dparts {
    my $x     = shift;
    my $class = ref $x;

    croak("dparts() is an instance method") unless $class;

    if ( $x->is_nan() ) {
        return $class->bnan(), $class->bnan() if wantarray;
        return $class->bnan();
    }

    if ( $x->is_inf() ) {
        return $class->binf( $x->sign() ), $class->bzero() if wantarray;
        return $class->binf( $x->sign() );
    }

    my ( $q, $r ) = $LIB->_div( $LIB->_copy( $x->{_n} ), $x->{_d} );

    my $int = Math::BigRat->new( $x->{sign} . $LIB->_str($q) );
    return $int unless wantarray;

    my $frc =
      Math::BigRat->new( $x->{sign} . $LIB->_str($r), $LIB->_str( $x->{_d} ) );

    return $int, $frc;
}

sub fparts {
    my $x     = shift;
    my $class = ref $x;

    croak("fparts() is an instance method") unless $class;

    return ( $class->bnan(), $class->bnan() ) if $x->is_nan();

    my $numer = $x->copy();
    my $denom = $class->bzero();

    $denom->{_n} = $numer->{_d};
    $numer->{_d} = $LIB->_one();

    return $numer, $denom;
}

sub numerator {
    my ( $class, $x ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    return Math::BigInt->new( $x->{sign} ) if !$x->is_finite();

    my $n = Math::BigInt->new( $LIB->_str( $x->{_n} ) );
    $n->{sign} = $x->{sign};
    $n;
}

sub denominator {
    my ( $class, $x ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    return Math::BigInt->new( $x->{sign} ) if $x->is_nan();
    return Math::BigInt->bone() if !$x->is_finite();

    Math::BigInt->new( $LIB->_str( $x->{_d} ) );
}

sub bstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( !$x->is_finite() ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $x->_upg()->bstr(@r)
      if $class->upgrade() && !$x->isa($class);

    my $s = '';
    $s = $x->{sign} if $x->{sign} ne '+';

    my $str = $x->{sign} eq '-' ? '-' : '';
    $str .= $LIB->_str( $x->{_n} );
    $str .= '/' . $LIB->_str( $x->{_d} ) unless $LIB->_is_one( $x->{_d} );
    return $str;
}

sub bsstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( !$x->is_finite() ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $x->_upg()->bsstr(@r)
      if $class->upgrade() && !$x->isa($class);

    my $str = $x->{sign} eq '-' ? '-' : '';
    $str .= $LIB->_str( $x->{_n} );
    $str .= '/' . $LIB->_str( $x->{_d} ) unless $LIB->_is_one( $x->{_d} );
    return $str;
}

sub bnstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bnstr(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    return $x->as_float(@r)->bnstr();
}

sub bestr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    $x->_upg()->bestr(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    return $x->as_float(@r)->bestr();
}

sub bdstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), @_ ) : objectify( 1, @_ );

    if ( $x->{sign} ne '+' && $x->{sign} ne '-' ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return ( $x->{sign} eq '-' ? '-' : '' ) . $LIB->_str( $x->{_n} )
      if $x->is_int();

    $x->_upg()->bdstr(@r)
      if $class->upgrade() && !$x->isa(__PACKAGE__);

    return $x->as_float(@r)->bdstr();
}

sub bfstr {
    my ( $class, $x, @r ) =
      ref( $_[0] ) ? ( ref( $_[0] ), $_[0] ) : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    if ( !$x->is_finite() ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $x->_upg()->bfstr(@r)
      if $class->upgrade() && !$x->isa($class);

    my $str = $x->{sign} eq '-' ? '-' : '';
    $str .= $LIB->_str( $x->{_n} );
    $str .= '/' . $LIB->_str( $x->{_d} ) unless $LIB->_is_one( $x->{_d} );
    return $str;
}

sub to_hex {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    if ( !$x->is_finite() ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $nan unless $x->is_int();

    my $str = $LIB->_to_hex( $x->{_n} );
    return $x->{sign} eq "-" ? "-$str" : $str;
}

sub to_oct {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    if ( !$x->is_finite() ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $nan unless $x->is_int();

    my $str = $LIB->_to_oct( $x->{_n} );
    return $x->{sign} eq "-" ? "-$str" : $str;
}

sub to_bin {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    if ( !$x->is_finite() ) {
        return $x->{sign} unless $x->is_inf("+");
        return 'inf';
    }

    return $nan unless $x->is_int();

    my $str = $LIB->_to_bin( $x->{_n} );
    return $x->{sign} eq "-" ? "-$str" : $str;
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

    return $LIB->_to_bytes( $x->{_n} );
}

sub to_ieee754 {
    my ( $class, $x, $format, @r ) =
      ref( $_[0] )
      ? ( ref( $_[0] ), @_ )
      : objectify( 1, @_ );

    carp "Rounding is not supported for ", ( caller(0) )[3], "()" if @r;

    return $x->as_float()->to_ieee754($format);
}

sub as_hex {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return $x unless $x->is_int();

    my $s = $x->{sign};
    $s = '' if $s eq '+';
    $s . $LIB->_as_hex( $x->{_n} );
}

sub as_oct {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return $x unless $x->is_int();

    my $s = $x->{sign};
    $s = '' if $s eq '+';
    $s . $LIB->_as_oct( $x->{_n} );
}

sub as_bin {
    my ( $class, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

    return $x unless $x->is_int();

    my $s = $x->{sign};
    $s = '' if $s eq '+';
    $s . $LIB->_as_bin( $x->{_n} );
}

sub numify {
    my ( $self, $x ) = ref( $_[0] ) ? ( undef, $_[0] ) : objectify( 1, @_ );

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

    my $abs =
        $LIB->_is_one( $x->{_d} )
      ? $LIB->_num( $x->{_n} )
      : Math::BigFloat->new( $LIB->_str( $x->{_n} ) )
      ->bfdiv( $LIB->_str( $x->{_d} ) )
      ->bstr();
    return $x->{sign} eq '-' ? 0 - $abs : 0 + $abs;
}

sub import {
    my $class = shift;
    $IMPORT++;
    my @a;

    my @import = ();

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
            push @import, $param;
            push @import, shift() if @_;
            next;
        }

        if ( $param eq 'with' ) {
            shift;
            next;
        }

        push @a, $param;
    }

    Math::BigInt->import(@import);

    $LIB = Math::BigInt->config("lib");

    $class->SUPER::import(@a);
    $class->export_to_level( 1, $class, @a ) if @a;
}

1;

__END__

