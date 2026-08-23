
package Image::ExifTool::TNEF;

use strict;
use vars            qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::ASF;
use Image::ExifTool::Microsoft;

$VERSION = '1.00';

sub ProcessProps($$$);

my %propType = (
    0x01  => 'null',
    0x02  => 'int16s',
    0x03  => 'int32s',
    0x04  => 'float',
    0x05  => 'double',
    0x06  => 'int64s',
    0x07  => 'double',
    0x0a  => 'int32s',
    0x0b  => 'int16s',
    0x0d  => 'undef',
    0x14  => 'int64s',
    0x1e  => 'string',
    0x1f  => 'Unicode',
    0x40  => 'int64u',
    0x48  => 'GUID',
    0x102 => 'undef',
);

my %fmtSize = (
    null   => 0,
    float  => 4,
    double => 8,
    GUID   => 16,
);

my %dateInfo = (
    Format    => 'date',
    Groups    => { 2 => 'Time' },
    PrintConv => '$self->ConvertDateTime($val)',
);

%Image::ExifTool::TNEF::Main = (
    GROUPS => { 0         => 'File', 1 => 'File', 2 => 'Other' },
    VARS   => { NO_LOOKUP => 1 },
    NOTES  => q{
        Information extracted from Transport Neutral Encapsulation Format (TNEF)
        files (eg. winmail.dat).  But note that the exiftool application doesn't
        process files with a .DAT extension by default when a directory name is
        given, so in this case either specify the .DAT file(s) by name or add
        C<-ext+ dat> to the command.
    },
    0x069007 => {
        Name          => 'CodePage',
        Format        => 'int32u',
        SeparateTable => 'Microsoft CodePage',
        RawConv =>
          '$val=~s/ .*//;$$self{Charset} = $charsetName{"cp$val"}; $val',
        PrintConv => \%Image::ExifTool::Microsoft::codePage,
    },
    0x089006 => {
        Name      => 'TNEFVersion',
        Format    => 'int8u',
        ValueConv => 'my @a = reverse split " ", $val; "@a"',
        PrintConv => '$val =~ tr/ /./; $val',
    },
    0x078008 => 'MessageClass',
    0x008000 => 'From',
    0x018004 => 'Subject',
    0x038005 => { Name => 'SentDate',     %dateInfo },
    0x038006 => { Name => 'ReceivedDate', %dateInfo },
    0x068007 => 'MessageStatus',
    0x018009 => 'MessageID',
    0x02800C => 'MessageBody',
    0x04800D => {
        Name      => 'Priority',
        Format    => 'int16u',
        PrintConv => {
            0 => 'Low',
            1 => 'Normal',
            2 => 'High',
        },
    },
    0x038020 => { Name => 'MessageModifyDate', %dateInfo },
    0x069003 => {
        Name         => 'MessageProps',
        SubDirectory => { TagTable => 'Image::ExifTool::TNEF::MsgProps' },
    },
    0x069004 => 'RecipientTable',
    0x070600 => 'OriginalMessageClass',
    0x060000 => 'Owner',
    0x060001 => 'SentFor',
    0x060002 => 'Delegate',
    0x030006 => { Name => 'StartDate', %dateInfo },
    0x030007 => { Name => 'EndDate',   %dateInfo },
    0x050008 => 'OwnerAppointmentID',
    0x040009 => 'ResponseRequested',
    0x06800F => { Name => 'AttachData', Binary => 1 },
    0x018010 => 'AttachTitle',
    0x068011 => { Name => 'AttachMetaFile',   Binary => 1 },
    0x038012 => { Name => 'AttachCreateDate', %dateInfo },
    0x038013 => { Name => 'AttachModifyDate', %dateInfo },
    0x069001 => 'AttachTransportFilename',
    0x069002 => { Name => 'AttachRenderingData', Binary => 1 },
    0x069005 => {
        Name         => 'AttachInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::TNEF::AttachInfo' },
    },
);

%Image::ExifTool::TNEF::MsgProps = (
    GROUPS       => { 0 => 'File', 1 => 'File', 2 => 'Other' },
    PROCESS_PROC => \&ProcessProps,
    TAG_PREFIX   => 'MsgProps',
    VARS         => { LONG_TAGS => 0, NO_LOOKUP => 1 },
    0x0002       => 'AlternateRecipientAllowed',
    0x0039       => { Name => 'ClientSubmitTime', %dateInfo },
    0x0040       => 'ReceivedByName',
    0x0044       => 'ReceivedRepresentingName',
    0x004d => { Name => 'OriginalAuthorName',   Groups => { 2 => 'Author' } },
    0x0055 => { Name => 'OriginalDeliveryTime', %dateInfo },
    0x0070 => 'Subject',
    0x0075 => 'ReceivedByAddressType',
    0x0076 => 'ReceivedByEmailAddress',
    0x0077 => 'ReceivedRepresentingAddressType',
    0x0078 => 'ReceivedRepresentingEmailAddress',
    0x007f => { Name => 'CorrelationKey', RawConv => '$$val' },
    0x0c1a => 'SenderName',
    0x0c1d =>
      { Name => 'SenderSearchKey', RawConv => 'ref $val ? $$val : $val' },
    0x0e06 => { Name => 'MessageDeliveryTime', %dateInfo },
    0x0e1d => 'NormalizedSubject',
    0x0e28 => 'PrimarySendAccount',
    0x0e29 => 'NextSendAccount',
    0x0f02 => { Name => 'DeliveryOrRenewTime', %dateInfo },
    0x1000 => { Name => 'MessageBodyText',     Binary => 1 },
    0x1007 => 'SyncBodyCount',
    0x1008 => 'SyncBodyData',
    0x1009 => {
        Name      => 'MessageBodyRTF',
        Notes     => 'RTF message body, decompressed if necessary',
        RawConv   => '$$val',
        ValueConv =>
          'my $dat = Image::ExifTool::TNEF::DecompressRTF($self,$val); \$dat',
    },
    0x1013 => { Name => 'MessageBodyHTML', Binary => 1 },
    0x1035 => 'InternetMessageID',
    0x10f4 => 'Hidden',
    0x10f6 => 'ReadOnly',
    0x3007 => { Name => 'CreateDate', %dateInfo },
    0x3008 => { Name => 'ModifyDate', %dateInfo },
    0x3fde => 'InternetCodePage',
    0x3ff1 => 'LocalUserID',
    0x3ff8 => { Name => 'CreatorName', Groups => { 2 => 'Author' } },
    0x3ffa => 'LastModifierName',
    0x3ffd => 'MessageCodePage',
    0x4076 => { Name => 'SpamConfidenceLevel' },
    '00020329_Author' => {
        Name   => 'Author',
        Groups => { 2 => 'Author' },
        Notes  => q{
            tag ID's for named properties are constructed from the property namespace
            GUID with the ending "-0000-0000-C000-000000000046" removed, followed by the
            string or numerical ID in hex, separated by an underscore
        },
    },
    '00020329_LastAuthor' =>
      { Name => 'LastAuthor', Groups => { 2 => 'Author' } },
    '00062004_0000801A' => 'HomeAddress',
    '00062004_000080DA' => 'HomeAddressCountryCode',
    '00062008_00008554' => 'AppVersion',
);

%Image::ExifTool::TNEF::AttachInfo = (
    GROUPS       => { 0 => 'File', 1 => 'File', 2 => 'Other' },
    PROCESS_PROC => \&ProcessProps,
    TAG_PREFIX   => 'Attach',
    0x0e20       => 'AttachSize',
    0x0e21       => 'AttachNum',
    0x0ff8       => { Name => 'MappingSignature', Unknown => 1 },
    0x3001       => 'AttachFileName',
    0x3703       => 'AttachFileExtension',
    0x3701       => 'AttachBinary',
    0x3705       => {
        Name      => 'AttachMethod',
        PrintConv => {
            0 => 'Attachment Created',
            1 => 'AttachData',
            2 => 'AttachLongPathName (recipients with access)',
            4 => 'AttachLongPathName',
            5 => 'Embedded Message',
            6 => 'AttachBinary (object)',
            7 => 'AttachLongPathName (using AttachmentProviderType)',
        },
    },
    0x3707 => 'AttachLongFileName',
    0x3708 => 'AttachPathName',
    0x370d => 'AttachLongPathName',
    0x370e => 'AttachMIMEType',
    0x7ffb => {
        Name => 'ExceptionStartTime',
        %dateInfo,
        Unknown => 1,
    },
    0x7ffc => { Name => 'ExceptionEndTime', Unknown => 1, %dateInfo },
);

sub DecompressRTF($$) {
    my ( $et, $cdat ) = @_;
    return '' unless length $cdat > 16;
    my $comp = unpack( 'x8V', $cdat );

    if ( $comp == 0x414c454D ) {
        return substr( $cdat, 16 );
    }
    elsif ( $comp != 0x75465a4c ) {
        $et->Warn( sprintf( 'Unknown RTF compression 0x%x', $comp ) );
        return '';
    }
    my $dict =
        '{\rtf1\ansi\mac\deff0\deftab720{\fonttbl;}'
      . '{\f0\fnil \froman \fswiss \fmodern '
      . '\fscript \fdecor MS Sans SerifSymbolArialTimes'
      . ' New RomanCourier{\colortbl\red0\green0\blue0' . "\r\n"
      . '\par \pard\plain\f0\fs20\b\i\u\tab\tx';
    my $cpos   = 16;
    my $clen   = length $cdat;
    my $dpos   = length $dict;
    my $rtnVal = '';
    while ( $cpos < $clen ) {
        my $control = unpack( 'C', substr( $cdat, $cpos++, 1 ) );
        my ( $i, $j );
        for ( $i = 0 ; $i < 8 && $cpos < $clen ; ++$i ) {
            if ( $control & ( 1 << $i ) ) {
                return $rtnVal if $cpos + 2 > $clen;
                my $ref = unpack( 'n', substr( $cdat, $cpos, 2 ) );
                $cpos += 2;
                my $off = $ref >> 4;
                my $len = ( $ref & 0x0f ) + 2;
                return $rtnVal
                  if $off == $dpos % 4096
                  or $off % 4096 >= length($dict);
                for ( $j = 0 ; $j < $len ; ++$j ) {
                    my $ch = substr( $dict, ( $off++ % 4096 ), 1 );
                    substr( $dict, ( $dpos++ % 4096 ), 1 ) = $ch;
                    $rtnVal .= $ch;
                }
            }
            else {
                my $ch = substr( $cdat, $cpos++, 1 );
                substr( $dict, ( $dpos++ % 4096 ), 1 ) = $ch;
                $rtnVal .= $ch;
            }
        }
    }
    return $rtnVal;
}

sub ProcessProps($$$) {
    my ( $et, $dirInfo, $tagTbl ) = @_;
    my $dataPt  = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dirLen  = length $$dataPt;
    return 0 unless $dirLen > 4;
    my $entries = unpack( 'V', $$dataPt );
    $et->VerboseDir( 'TNEF Properties', $entries );
    my $pos = 4;
    my $i;

    for ( $i = 0 ; $i < $entries ; ++$i ) {
        last if $pos + 4 > $dirLen;
        my $type = Get16u( $dataPt, $pos );
        my $tag  = Get16u( $dataPt, $pos + 2 );
        $pos += 4;
        if ( $tag & 0x8000 ) {
            last if $pos + 24 > $dirLen;
            my $uid =
              Image::ExifTool::ASF::GetGUID( substr( $$dataPt, $pos, 16 ) );
            $uid =~ s/-0000-0000-C000-000000000046$//;
            my $idtype = Get32u( $dataPt, $pos + 16 );
            my $num    = Get32u( $dataPt, $pos + 20 );
            $pos += 24;
            if ( $idtype == 0 ) {
                $tag = $uid . sprintf( '_%.8x', $num );
            }
            elsif ( $idtype == 1 ) {
                last if $pos + $num > $dirLen or $num < 2;
                my $name =
                  $et->Decode( substr( $$dataPt, $pos, $num - 2 ), 'UTF16' );
                $tag = "${uid}_$name";
                AddTagToTable(
                    $tagTbl, $tag,
                    {
                        Name => Image::ExifTool::MakeTagName($name)
                    }
                ) unless $$tagTbl{$tag};
                $pos += ( $num + 3 ) & 0xfffffffc;
            }
            else {
                last;
            }
        }
        my $count = 1;
        my ( $multi, $fmt );
        if ( $type & 0x1000 ) {
            $multi = 1;
            $type &= 0x0fff;
            last if $pos + 4 > $dirLen;
            $count = Get32u( $dataPt, $pos );
            $pos += 4;
        }
        $fmt = $propType{$type} or last;
        while ($count) {
            my $size = $fmtSize{$fmt};
            my $val;
            unless ($size) {
                if ( $fmt =~ /(\d+)/ ) {
                    $size = $count * $1 / 8;
                }
                elsif ( $fmt eq 'null' ) {
                    $val = '';
                }
                else {
                    $pos += 4 unless $multi;
                    last if $pos + 4 > $dirLen;
                    $size = Get32u( $dataPt, $pos );
                    $pos += 4;
                    last if $pos + $size > $dirLen;
                    $val = substr( $$dataPt, $pos, $size );
                }
            }
            if ( not defined $val ) {
                $val = ReadValue( $dataPt, $pos, $fmt, $count, $size );
                if (   $type == 0x06
                    or $type == 0x07
                    or $type == 0x0b
                    or $type == 0x40 )
                {
                    my @a = split ' ', $val;
                    if ( $type == 0x06 ) {
                        $_ = $_ / 10000 foreach @a;
                    }
                    elsif ( $type == 0x07 ) {

                        foreach (@a) {
                            $_ = ( $_ - 25569 ) * 24 * 3600 if $_ != 0;
                            $_ = Image::ExifTool::ConvertUnixTime($_);
                        }
                    }
                    elsif ( $type == 0x0b ) {
                        $_ = $_ ? 'True' : 'False' foreach @a;
                    }
                    elsif ( $type == 0x40 ) {

                        $_ = Image::ExifTool::ConvertUnixTime(
                            $_ / 1e7 - 11644473600, 1 )
                          foreach @a;
                    }
                    $val = @a > 1 ? \@a : $a[0];
                }
                $count = 1;
            }
            elsif ( $fmt eq 'GUID' ) {
                $val = Image::ExifTool::ASF::GetGUID($val);
            }
            elsif ( $fmt eq 'Unicode' ) {
                ( $val = $et->Decode( $val, 'UTF16' ) ) =~ s/\0+$//;
            }
            elsif ( $fmt eq 'string' ) {
                $val =~ s/\0+$//;
                $val = $et->Decode( $val, $$et{Charset} ) if $$et{Charset};
            }
            elsif ( $fmt eq 'undef' and length $val ) {
                my $copy = $val;
                $val = \$copy;
            }
            $et->HandleTag(
                $tagTbl, $tag, $val,
                DataPt  => $dataPt,
                DataPos => $dataPos,
                Start   => $pos,
                Size    => $size,
                Format  => sprintf( '%s, type 0x%.2x', $fmt, $type ),
                Index   => $i,
            );
            $pos += ( $size + 3 ) & 0xfffffffc;
            --$count;
        }
    }
    $et->Warn('Error parsing message properties') unless $i == $entries;
    return 1;
}

sub ProcessTNEF($$) {
    my ( $et, $dirInfo ) = @_;
    my $raf = $$dirInfo{RAF};
    my ( $buff, $tagTablePtr );

    return 0 unless $raf->Read( $buff, 0x15 ) == 0x15 and $raf->Seek( 6, 0 );
    return 0 unless $buff =~ /^\x78\x9f\x3e\x22..\x01\x06\x90\x08\0/s;
    $et->SetFileType('TNEF');
    SetByteOrder('II');
    my $tagTbl = GetTagTable('Image::ExifTool::TNEF::Main');
    while ( $raf->Read( $buff, 9 ) == 9 ) {
        my ( $tag, $len ) = unpack( 'x1VV', $buff );
        $$et{DOC_NUM} = ++$$et{DOC_COUNT} if $tag == 0x069002;
        $raf->Read( $buff, $len ) == $len or last;
        my $tagInfo = $$tagTbl{$tag};
        my ( $val, $fmt );
        if ( $tagInfo and $$tagInfo{Format} ) {
            $fmt = $$tagInfo{Format};
            if ( $fmt eq 'date' and length($buff) >= 12 ) {
                my @date = unpack( 'v6', $buff );
                $val = sprintf( '%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @date );
            }
        }
        else {
            $val = $buff;
        }
        $et->HandleTag(
            $tagTbl, $tag, $val,
            DataPt  => \$buff,
            DataPos => $raf->Tell() - $len,
            Format  => $fmt,
        );
        delete $$et{DOC_NUM} if $tag == 0x069005;
        $raf->Seek( 2, 1 );
    }
    delete $$et{DOC_NUM};
    return 1;
}

1;

__END__

