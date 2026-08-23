
package Image::ExifTool::Trailer;

use strict;
use vars            qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.01';

%Image::ExifTool::Trailer::Vivo = (
    GROUPS => { 0      => 'Trailer', 1 => 'Vivo', 2 => 'Image' },
    VARS   => { ID_FMT => 'none' },
    NOTES  => 'Information written in JPEG trailer by some Vivo phones.',
    HDRImage => {
        Notes  => 'highlights of HDR image',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    JSONInfo   => {},
    HiddenData => {
        Notes =>
'hidden in EXIF, not in trailer.  This data is lost if the file is edited',
        Groups => { 0 => 'EXIF' },
    },
);

%Image::ExifTool::Trailer::OnePlus = (
    GROUPS   => { 0 => 'Trailer', 1 => 'OnePlus', 2 => 'Image' },
    NOTES    => 'Information written in JPEG trailer by some OnePlus phones.',
    JSONInfo => {},
    'private.emptyspace' => {
        Name      => 'OnePlusTrailerLen',
        ValueConv => 'length $val == 4 ? unpack("N", $val) : $val',
        Unknown   => 1,
    },
    'watermark.device' => {
        Name      => 'Device',
        ValueConv => '"0x" . join(" ", unpack("H10Z*", $val))',
        Format    => 'string',
    },
);

%Image::ExifTool::Trailer::Google = (
    GROUPS => { 0 => 'Trailer', 1 => 'Google', 2 => 'Image' },
    NOTES  => q{
        Google-defined information written in the trailer of JPEG images by some
        phones.  This information is referenced by DirectoryItem entries in the XMP.
        Note that some of this information may also be referenced from other
        metadata formats, and hence may be extracted twice.  For example,
        MotionPhotoVideo may also exist within a Samsung trailer as
        EmbbededVideoFile, or GainMapImage may also exist in an MPF trailer as
        MPImage2.
    },
    MotionPhoto => { Name => 'MotionPhotoVideo', Groups => { 2 => 'Video' } },
    GainMap     => { Name => 'GainMapImage',     Groups => { 2 => 'Preview' } },
    Depth       => { Name => 'DepthMapImage',    Groups => { 2 => 'Preview' } },
    Confidence  =>
      { Name => 'ConfidenceMapImage', Groups => { 2 => 'Preview' } },
    'android/depthmap' =>
      { Name => 'DepthMapImage', Groups => { 2 => 'Preview' } },
    'android/confidencemap' =>
      { Name => 'ConfidenceMapImage', Groups => { 2 => 'Preview' } },
);

sub ProcessVivo($$) {
    my ( $et, $dirInfo ) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    return -1 unless $$dirInfo{ScanForTrailer};

    my $pos = $$et{TrailerStart} or return 0;
    my $len = $$et{FileEnd} - $pos - $$dirInfo{Offset};
    $raf->Seek( $pos, 0 ) or return 0;
    return 0
      unless $len > 0
      and $len < 1e7
      and $raf->Read( $buff, $len ) == $len
      and $buff =~ /\xff{4}\x1b\*9HWfu\x84\x93\xa2\xb1$/
      and $buff =~ /(streamdata|vivo\{")/g;
    my $start = pos($buff) - length($1);

    if ($start) {
        $pos += $start;
        $len -= $start;
        $buff = substr( $buff, $start );
    }
    @$dirInfo{ 'DataPos', 'DirLen' } = ( $pos, $len );

    return -1 if $$dirInfo{OutFile};

    $et->DumpTrailer($dirInfo) if $$et{OPTIONS}{Verbose} or $$et{HTML_DUMP};
    my $tbl = GetTagTable('Image::ExifTool::Trailer::Vivo');
    pos($buff) = 0;
    if (    $buff =~ /^streamdata\xff\xd8\xff/
        and $buff =~ /\xff\xd9stream(info|coun)/g )
    {
        $et->HandleTag( $tbl,
            HDRImage => substr( $buff, 10, pos($buff) - 20 ) );
    }
    if ( $buff =~ /vivo\{"/g ) {
        my $jsonStart = pos($buff) - 2;
        if ( $buff =~ /\}\0/g ) {
            my $jsonLen = pos($buff) - 1 - $jsonStart;
            $et->HandleTag( $tbl,
                JSONInfo => substr( $buff, $jsonStart, $jsonLen ) );
        }
    }
    return 1;
}

sub ProcessOnePlus($$) {
    my ( $et, $dirInfo ) = @_;
    my $raf = $$dirInfo{RAF};
    my ( $buff, $buf2 );

    return -1 unless $$dirInfo{ScanForTrailer};

    return -1 if $$dirInfo{OutFile};

    my $start = $$et{TrailerStart} or return 0;
    $raf->Seek( -8 - $$dirInfo{Offset}, 2 ) and $raf->Read( $buff, 8 ) == 8
      or return 0;
    my $end = $raf->Tell();

    my $dump     = ( $$et{OPTIONS}{Verbose} or $$et{HTML_DUMP} );
    my $tagTable = GetTagTable('Image::ExifTool::Trailer::OnePlus');
    my $trailLen = 0;
    if ( $buff =~ /^jxrs...\0$/ ) {
        my $jlen   = unpack( 'x4V', $buff );
        my $maxOff = 0;
        if (    $jlen < $end - $start
            and $jlen > 8
            and $raf->Seek( $end - $jlen )
            and $raf->Read( $buff, $jlen - 8 ) == $jlen - 8 )
        {
            $buff =~ s/\0+$//;
            require Image::ExifTool::Import;
            my $list = Image::ExifTool::Import::ReadJSONObject( undef, \$buff );
            if ( ref $list eq 'ARRAY' ) {
                $$_{offset} and $$_{offset} > $maxOff and $maxOff = $$_{offset}
                  foreach @$list;
                $trailLen = $maxOff + $jlen;
                if ( $dump and $trailLen ) {
                    $et->DumpTrailer(
                        {
                            RAF     => $raf,
                            DirName => 'OnePlus',
                            DataPos => $end - $trailLen,
                            DirLen  => $trailLen,
                        }
                    );
                }
                $et->HandleTag( $tagTable, JSONInfo => $buff );
                foreach (@$list) {
                    my ( $off, $name, $len ) = @$_{qw(offset name length)};
                    next unless $off and $name and $len;
                    if (    $raf->Seek( $end - $jlen - $off )
                        and $raf->Read( $buf2, $len ) == $len )
                    {
                        $et->HandleTag(
                            $tagTable, $name, $buf2,
                            DataPos => $end - $jlen - $off,
                            DataPt  => \$buf2
                        );
                    }
                }
            }
            else {
                $et->HandleTag( $tagTable, JSONInfo => $buff );
                $et->Warn('Error parsing OnePlus JSON information');
            }
        }
    }
    @$dirInfo{ 'DataPos', 'DirLen' } = ( $end - $trailLen, $trailLen );

    return 1;
}

sub ProcessGoogle($$) {
    my ( $et, $dirInfo ) = @_;
    my $raf  = $$dirInfo{RAF};
    my $info = $$et{VALUE};

    my ( $tag, $mime, $len, $pad ) = @$info{
        qw(DirectoryItemSemantic DirectoryItemMime
          DirectoryItemLength DirectoryItemPadding)
    };

    unless ( ref $tag eq 'ARRAY' and ref $mime eq 'ARRAY' ) {
        undef $pad;
        ( $tag, $mime, $len ) = @$info{
            qw(ContainerDirectoryItemDataURI
              ContainerDirectoryItemMime ContainerDirectoryItemLength)
        };
        unless ( ref $mime eq 'ARRAY' and ref $tag eq 'ARRAY' ) {
            delete $$et{ProcessGoogleTrailer};
            return 0;
        }
    }
    return -1 unless $$dirInfo{ScanForTrailer};

    delete $$et{ProcessGoogleTrailer};

    return -1 if $$dirInfo{OutFile};

    $len = [$len] unless ref $len eq 'ARRAY';
    unshift @$len, 0 while @$len < @$mime;

    my $start = $$et{TrailerStart} or return 0;
    my $end   = $$et{FileEnd};

    my $dump     = ( $$et{OPTIONS}{Verbose} or $$et{HTML_DUMP} );
    my $tagTable = GetTagTable('Image::ExifTool::Trailer::Google');

    my ( $i, $pos, $buff, $regex, $grp, $type );
    for ( $i = 1, $pos = 0 ; defined $$mime[$i] ; ++$i ) {
        my $more = $end - $start - $pos;
        last if $more < 16;
        next unless $$len[$i] and defined $$tag[$i];
        last if $$len[$i] > $more;
        $raf->Seek( $start + $pos )
          and $raf->Read( $buff, 16 ) == 16
          and $raf->Seek( $start + $pos )
          or last;
        if ( $$mime[$i] eq 'image/jpeg' ) {
            $regex = '\xff\xd8\xff[\xdb\xe0\xe1]';
        }
        elsif ( $$mime[$i] eq 'video/mp4' ) {
            $regex = '\0\0\0.ftyp(mp42|isom)';
        }
        else {
            $et->Warn("Google trailer $$tag[$i] $$mime[$i] not handled");
            next;
        }
        if ( $buff =~ /^$regex/s ) {
            last unless $raf->Read( $buff, $$len[$i] ) == $$len[$i];
        }
        else {
            last if $pos;
            last unless $raf->Read( $buff, $more ) == $more;
            last unless $buff =~ /($regex)/sg;
            $pos += pos($buff) - length($1);
            $more = $end - $start - $pos;
            last if $$len[$i] > $end - $start - $pos;
            $buff = substr( $buff, $pos, $$len[$i] );
        }
        unless ( $$tagTable{ $$tag[$i] } ) {
            my $name = $$tag[$i];
            $name =~ s/([^A-Za-z])([a-z])/$1\u$2/g;
            $name = Image::ExifTool::MakeTagName( $$tag[$i] );
            if ( $$mime[$i] eq 'image/jpeg' ) {
                ( $type, $grp ) = ( 'Image', 'Preview' );
            }
            else {
                ( $type, $grp ) = ( 'Video', 'Video' );
            }
            $et->VPrint( 0, $$et{INDENT}, "[adding Google:$name]\n" );
            AddTagToTable( $tagTable, $$tag[$i],
                { Name => "$name$type", Groups => { 2 => $grp } } );
        }
        $dump and $et->DumpTrailer(
            {
                RAF     => $raf,
                DirName => $$tag[$i],
                DataPos => $start + $pos,
                DirLen  => $$len[$i],
            }
        );
        $et->HandleTag(
            $tagTable, $$tag[$i], \$buff,
            DataPos => $start + $pos,
            DataPt  => \$buff
        );
        $pos += $$len[$i] + ( ( $pad and $$pad[$i] ) ? $$pad[$i] : 0 );
    }
    if ( defined $$tag[$i] and defined $$mime[$i] ) {
        $et->Warn( "Error reading $$tag[$i] $$mime[$i] from trailer", 1 );
    }
    return 0 unless $pos;

    @$dirInfo{ 'DataPos', 'DirLen' } = ( $start, $pos );

    return 1;
}

1;

__END__


