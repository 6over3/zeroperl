
package Image::ExifTool::Protobuf;

use strict;
use vars            qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

sub ProcessProtobuf($$$;$);

my $intMax = ~0;

my $int64sMin = 18446744069414584320;

sub GetBytes($$) {
    my ( $dirInfo, $n ) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos    = $$dirInfo{Pos};
    return undef if $pos + $n > length $$dataPt;
    $$dirInfo{Pos} += $n;
    return substr( $$dataPt, $pos, $n );
}

sub VarInt($) {
    my $dirInfo = shift;
    my $buff    = GetBytes( $dirInfo, 1 );
    return undef unless defined $buff;
    my $val = ord($buff) & 0x7f;
    $$dirInfo{Bit0} = $val & 0x01;
    my $mult = 128;
    my $i    = 0;
    for ( ; ; ) {
        last unless ord($buff) & 0x80;
        $buff = GetBytes( $dirInfo, 1 );
        return undef unless defined $buff;
        $val += ( ord($buff) & 0x7f ) * $mult;
        last unless ord($buff) & 0x80;
        return undef if ++$i > 32;
        $mult *= 128;
    }
    return $val;
}

sub ReadRecord($) {
    my $dirInfo = shift;
    my $val     = VarInt($dirInfo);
    return undef unless defined $val;
    my $id   = $val >> 3;
    my $type = $val & 0x07;
    my $buff;

    if ( $type == 0 ) {
        $buff = VarInt($dirInfo);
    }
    elsif ( $type == 1 ) {
        $buff = GetBytes( $dirInfo, 8 );
    }
    elsif ( $type == 2 ) {
        my $len = VarInt($dirInfo);
        if ($len) {
            $buff = GetBytes( $dirInfo, $len );
        }
        else {
            $buff = '';
        }
    }
    elsif ( $type == 3 ) {
        $buff = '';
    }
    elsif ( $type == 4 ) {
        $buff = '';
    }
    elsif ( $type == 5 ) {
        $buff = GetBytes( $dirInfo, 4 );
    }
    return wantarray ? ( $buff, $id, $type ) : $buff;
}

sub IsProtobuf($) {
    my $pt      = shift;
    my $dirInfo = { DataPt => $pt, Pos => 0 };
    for ( ; ; ) {
        return 0 unless defined ReadRecord($dirInfo);
        return 1 if $$dirInfo{Pos} == length $$pt;
    }
}

sub ProcessProtobuf($$$;$) {
    my ( $et, $dirInfo, $tagTbl, $prefix ) = @_;
    my $dataPt   = $$dirInfo{DataPt};
    my $dirName  = $$dirInfo{DirName};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen   = $$dirInfo{DirLen}   || ( length($$dataPt) - $dirStart );
    my $dirEnd   = $dirStart + $dirLen;
    my $dataPos  = ( $$dirInfo{Base} || 0 ) + ( $$dirInfo{DataPos} || 0 );
    my $unknown  = $et->Options('Unknown') || $et->Options('Verbose');

    $$dirInfo{Pos} = $$dirInfo{DirStart} || 0;
    $et->VerboseDir( 'Protobuf', undef, $dirLen );
    unless ($prefix) {
        $prefix = '';
        $$et{ProtoPrefix}{$dirName} = ''
          unless defined $$et{ProtoPrefix}{$dirName};
        SetByteOrder('II');
    }
    my $unkPre =
      $$tagTbl{TAG_PREFIX} ? $$tagTbl{TAG_PREFIX} . '_' : 'Protobuf ';

    for ( ; ; ) {
        my $pos = $$dirInfo{Pos};
        last if $pos >= $dirEnd;
        my ( $buff, $id, $type ) = ReadRecord($dirInfo);
        defined $buff or $et->Warn('Protobuf format error'), last;
        if ( $type == 2 and $buff =~ /\.proto$/ ) {
            $$et{ProtoPrefix}{$dirName} = substr( $buff, 0, -6 ) . '_';
            $et->HandleTag( $tagTbl, Protocol => $buff );
        }
        my $tag     = "$$et{ProtoPrefix}{$dirName}$prefix$id";
        my $tagInfo = $$tagTbl{$tag};
        if ($tagInfo) {
            next if $type != 2 and $$tagInfo{Unknown} and not $unknown;
        }
        else {
            next unless $type == 2 or $unknown;
            $tagInfo = AddTagToTable( $tagTbl, $tag, { Unknown => 1 } );
        }
        if ( $type == 2 and $$tagInfo{Unknown} ) {
            if ( $$tagInfo{IsProtobuf} ) {
                $$tagInfo{IsProtobuf} = 0 unless IsProtobuf( \$buff );
            }
            elsif ( not defined $$tagInfo{IsProtobuf}
                and $buff =~ /[^\x20-\x7e]/
                and IsProtobuf( \$buff ) )
            {
                $$tagInfo{IsProtobuf} = 1;
            }
            next unless $$tagInfo{IsProtobuf} or $unknown;
        }
        my $val;
        if ( $$tagInfo{Format} ) {
            if ( $type == 0 ) {
                $val = $buff;
                if ( $$tagInfo{Format} eq 'signed' ) {
                    if ( $val > $intMax ) {
                        $val =
                          $$dirInfo{Bit0} ? -int( $val / 2 ) - 1 : $val / 2;
                    }
                    else {
                        $val =
                          ( $val & 1 ) ? -( $val >> 1 ) - 1 : ( $val >> 1 );
                    }
                }
                elsif ( $$tagInfo{Format} eq 'int64s' and $val >= $int64sMin ) {
                    $val = $val - $int64sMin - 4294967296;
                }
            }
            elsif ( $type == 2 and $$tagInfo{Format} eq 'rational' ) {
                my $dir = { DataPt => \$buff, Pos => 0 };
                my $num = VarInt($dir);
                my $den = VarInt($dir);
                $val = ( defined $num and $den ) ? $num / $den : 'err';
            }
            else {
                $val = ReadValue( \$buff, 0, $$tagInfo{Format}, undef,
                    length($buff) );
            }
        }
        elsif ( $type == 0 ) {
            $val = $buff;
            my $hex = sprintf( '%x', $val );
            if ( $val >= $int64sMin ) {
                my $s64 = $val - $int64sMin - 4294967296;
                $val .= " (0x$hex, int64s $s64)";
            }
            else {
                my $signed;
                if ( $val > $intMax ) {
                    $signed = $$dirInfo{Bit0} ? -int( $val / 2 ) - 1 : $val / 2;
                }
                else {
                    $signed = ( $val & 1 ) ? -( $val >> 1 ) - 1 : ( $val >> 1 );
                }
                $val .= " (0x$hex, signed $signed)";
            }
        }
        elsif ( $type == 1 ) {
            $val = '0x'
              . unpack( 'H*', $buff )
              . ' (double '
              . GetDouble( \$buff, 0 ) . ')';
        }
        elsif ( $type == 2 ) {
            if ( $$tagInfo{SubDirectory} ) {
            }
            elsif ( $$tagInfo{IsProtobuf} ) {
                $et->VPrint( 1,
                        "$$et{INDENT}${unkPre}$tag ("
                      . length($buff)
                      . " bytes) -->\n" );
                my $addr = $dataPos + $$dirInfo{Pos} - length($buff);
                $et->VerboseDump(
                    \$buff,
                    Addr   => $addr,
                    Prefix => $$et{INDENT}
                );
                my %subdir =
                  ( DataPt => \$buff, DataPos => $addr, DirName => $dirName );
                $$et{INDENT} .= '| ';
                ProcessProtobuf( $et, \%subdir, $tagTbl, "$prefix$id-" );
                $$et{INDENT} = substr( $$et{INDENT}, 0, -2 );
                next;
            }
            else {
                my $rat;
                my %dir = ( DataPt => \$buff, Pos => 0 );
                my $num = VarInt( \%dir );
                if ( defined $num ) {
                    my $denom = VarInt( \%dir );
                    $rat = " (rational $num/$denom)"
                      if $denom and $dir{Pos} == length($buff);
                }
                if ( $buff !~ /[^\r\n\t\x20-\x7e]/ ) {
                    $val = $buff;
                }
                elsif ( length($buff) % 4 ) {
                    $val = '0x' . unpack( 'H*', $buff );
                }
                else {
                    my $n = length($buff) / 4;
                    $val = '0x' . join( ' ', unpack( "(H8)$n", $buff ) );
                }
                $val .= $rat if $rat;
            }
        }
        elsif ( $type == 5 ) {
            $val =
              '0x' . unpack( 'H*', $buff ) . ' (int32u ' . Get32u( \$buff, 0 );
            $val .= ', int32s ' . Get32s( \$buff, 0 )
              if ord( substr( $buff, 3, 1 ) ) & 0x80;
            $val .= ', float ' . GetFloat( \$buff, 0 ) . ')';
        }
        else {
            $val = $buff;
        }
        my $start = $type == 0 ? $pos + 1 : $$dirInfo{Pos} - length $buff;
        $et->HandleTag(
            $tagTbl, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $start,
            Size    => $$dirInfo{Pos} - $start,
            Extra   => ", type=$type",
            Format  => $$tagInfo{Format},
        );
    }
    $et->Warn('Truncated protobuf data')
      unless $prefix
      or $$dirInfo{Pos} == $dirEnd;
    return 1;
}

1;

__END__

