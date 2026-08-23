
package Image::ExifTool::GoPro;

use strict;
use vars            qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::QuickTime;

$VERSION = '1.15';

sub ProcessGoPro($$$);
sub ProcessString($$$);
sub ScaleValues($$);
sub AddUnits($$$);
sub ConvertSystemTime($$);

my %goProFmt = (

    0x62 => 'int8s',
    0x42 => 'int8u',
    0x63 => 'string',
    0x73 => 'int16s',
    0x53 => 'int16u',
    0x6c => 'int32s',
    0x4c => 'int32u',
    0x66 => 'float',
    0x64 => 'double',
    0x46 => 'undef',
    0x47 => 'undef',
    0x6a => 'int64s',
    0x4a => 'int64u',
    0x71 => 'fixed32s',
    0x51 => 'fixed64s',
    0x55 => 'undef',
    0x3f => 'undef',
);

my %goProSize = (
    0x46 => 4,
    0x47 => 16,
    0x55 => 16,
);

my %addUnits = (
    AddUnits  => 1,
    PrintConv => 'Image::ExifTool::GoPro::AddUnits($self, $val, $tag)',
);

my %noYes = ( N => 'No', Y => 'Yes' );

%Image::ExifTool::GoPro::GPMF = (
    PROCESS_PROC => \&ProcessGoPro,
    GROUPS       => { 2 => 'Camera' },
    NOTES        => q{
        Tags extracted from the GPMF box of GoPro MP4 videos, the APP6 "GoPro"
        segment of JPEG files, and from the "gpmd" timed metadata if the
        L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> (-ee) option is enabled.  Many more tags exist, but are
        currently unknown and extracted only with the L<Unknown|../ExifTool.html#Unknown> (-u) option. Please
        let me know if you discover the meaning of any of these unknown tags. See
        L<https://github.com/gopro/gpmf-parser> for details about this format.
    },
    ABSC => 'AutoBoostScore',
    ACCL => {
        Name   => 'Accelerometer',
        Notes  => 'accelerator readings in m/s2',
        Binary => 1,
    },
    ALLD => 'AutoLowLightDuration',
    APTO => 'AudioProtuneOption',
    ARUW => 'AspectRatioUnwarped',
    ARWA => 'AspectRatioWarped',
    ATTD => {
        Name => 'Attitude',
        Binary => 1,
    },
    ATTR => {
        Name => 'AttitudeTarget',
        Binary => 1,
    },
    AUBT => { Name => 'AudioBlueTooth', PrintConv => \%noYes },
    AUDO => 'AudioSetting',
    AUPT => { Name => 'AutoProtune', PrintConv => \%noYes },
    BITR => 'BitrateSetting',
    BPOS => {
        Name    => 'Controller',
        Unknown => 1,
        %addUnits,
    },
    CASN => 'CameraSerialNumber',
    CDAT => {
        Name      => 'CreationDate',
        Groups    => { 2 => 'Time' },
        RawConv   => 'ConvertUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    CDTM => 'CaptureDelayTimer',

    CLDP => { Name => 'ClassificationDataPresent', PrintConv => \%noYes },
    CPIN => 'ChapterNumber',
    CSEN => {
        Name => 'CoyoteSense',
        Binary => 1,
    },
    CTRL => 'ControlLevel',
    CYTS => {
        Name => 'CoyoteStatus',
        Binary => 1,
    },
    DEVC => {
        Name         => 'DeviceContainer',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPMF' },
    },
    DUST => 'DurationSetting',

    DVID => { Name => 'DeviceID', Unknown => 1 },

    DVNM => 'DeviceName',
    DZOM => {
        Name      => 'DigitalZoomOn',
        PrintConv => \%noYes,
    },
    DZMX => 'DigitalZoomAmount',
    DZST => 'DigitalZoom',
    EISA => {
        Name => 'ElectronicImageStabilization',
    },
    EISE => { Name => 'ElectronicStabilizationOn', PrintConv => \%noYes },
    EMPT => { Name => 'Empty',                     Unknown   => 1 },
    ESCS => {
        Name => 'EscapeStatus',
        Unknown => 1,
        %addUnits,
    },
    EXPT => 'ExposureType',
    FACE => 'FaceDetected',
    FCNM => 'FaceNumbers',
    FMWR => 'FirmwareVersion',
    FWVS => 'OtherFirmware',
    GLPI => {
        Name => 'GPSPos',
        RawConv      => '$val',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GLPI' },
    },
    GPRI => {
        Name => 'GPSRaw',
        Unknown      => 1,
        RawConv      => '$val',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPRI' },
    },
    GPS5 => {
        Name => 'GPSInfo',
        RawConv      => '$val',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPS5' },
    },
    GPS9 => {
        Name => 'GPSInfo9',
        RawConv      => '$val',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPS9' },
    },
    GPSF => {
        Name      => 'GPSMeasureMode',
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    GPSP => {
        Name        => 'GPSHPositioningError',
        Description => 'GPS Horizontal Positioning Error',
        ValueConv   => '$val / 100',
    },
    GPSU => {
        Name   => 'GPSDateTime',
        Groups => { 2 => 'Time' },
        ValueConv =>
'$val =~ s/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/20$1:$2:$3 $4:$5:/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    GYRO => {
        Name   => 'Gyroscope',
        Notes  => 'gyroscope readings in rad/s',
        Binary => 1,
    },
    LOGS => 'HealthLogs',
    HCTL => 'HorizonControl',
    HDRV => { Name => 'HDRVideo', PrintConv => \%noYes },

    HSGT => 'HindsightSettings',
    ISOE => 'ISOSpeeds',
    ISOG => {
        Name   => 'ImageSensorGain',
        Binary => 1,
    },
    KBAT => {
        Name => 'BatteryStatus',
        RawConv      => '$val',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::KBAT' },
    },
    LNED => {
        Name => 'LocalPositionNED',
        Binary => 1,
    },
    MAGN => 'Magnetometer',
    MAPX => 'MappingXCoefficients',
    MAPY => 'MappingYCoefficients',

    MINF => {
        Name        => 'Model',
        Groups      => { 2 => 'Camera' },
        Description => 'Camera Model Name',
    },
    MMOD => 'MediaMode',

    MUID => {
        Name      => 'MediaUID',
        ValueConv => 'join("-", unpack("H8H4H4H4H12", $val))'
    },
    MXCF => 'MappingXMode',
    MYCF => 'MappingYMode',
    ORDP => { Name => 'OrientationDataPresent', PrintConv => \%noYes },
    OREN => {
        Name      => 'AutoRotation',
        PrintConv => {
            U => 'Up',
            D => 'Down',
            A => 'Auto',
        },
    },
    PHDR => 'HDRSetting',
    PIMD => 'ProtuneISOMode',
    PIMN => 'AutoISOMin',
    PIMX => 'AutoISOMax',
    POLY => 'PolynomialCoefficients',

    PRES => 'PhotoResolution',
    PRJT => 'LensProjection',

    PRTN => {
        Name      => 'Protune',
        PrintConv => {
            N => 'Off',
            Y => 'On',
        },
    },
    PTCL => 'ColorMode',
    PTEV => 'ExposureCompensation',
    PTSH => 'Sharpness',
    PTWB => 'WhiteBalance',

    PWPR => 'PowerProfile',
    PYCF => 'PolynomialPower',
    RAMP => 'SpeedRampSetting',
    RATE => 'Rate',
    RMRK => {
        Name      => 'Comments',
        ValueConv => '$self->Decode($val, "Latin")',
    },
    SCAL => {
        Name    => 'ScaleFactor',
        Unknown => 1,
    },
    SCAP => { Name => 'ScheduleCapture', PrintConv => \%noYes },
    SCPR => {
        Name => 'ScaledPressure',
        %addUnits,
    },
    SCTM => 'ScheduleCaptureTime',

    SHUT => {
        Name      => 'ExposureTimes',
        PrintConv => q{
            my @a = split ' ', $val;
            $_ = Image::ExifTool::Exif::PrintExposureTime($_) foreach @a;
            return join ' ', @a;
        },
    },
    SIMU => {
        Name => 'ScaledIMU',
        %addUnits,
    },
    SIUN => {
        Name      => 'SIUnits',
        Unknown   => 1,
        ValueConv => '$self->Decode($val, "Latin")',
    },
    SMTR => { Name => 'SpotMeter', PrintConv => \%noYes },

    SROT => 'SensorReadoutTime',
    STMP => {
        Name      => 'TimeStamp',
        ValueConv => '$val / 1e6',
    },
    STRM => {
        Name         => 'NestedSignalStream',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPMF' },
    },
    STNM => {
        Name      => 'StreamName',
        Unknown   => 1,
        ValueConv => '$self->Decode($val, "Latin")',
    },
    SYST => {
        Name => 'SystemTime',
        RawConv => q{
            my @v = split ' ', $val;
            if (@v == 2) {
                my $s = $$self{SystemTimeList};
                $s or $s = $$self{SystemTimeList} = [ ];
                push @$s, \@v;
            }
            return $val;
        },
    },
    TMPC => {
        Name      => 'CameraTemperature',
        PrintConv => '"$val C"',
    },
    TSMP => { Name => 'TotalSamples', Unknown => 1 },
    TIMO => 'TimeOffset',
    TYPE => { Name => 'StructureType', Unknown => 1 },
    TZON => {
        Name      => 'TimeZone',
        PrintConv => 'Image::ExifTool::TimeZoneString($val)',
    },
    UNIT => {
        Name      => 'Units',
        Unknown   => 1,
        ValueConv => '$self->Decode($val, "Latin")',
    },
    VERS => {
        Name      => 'MetadataVersion',
        PrintConv => '$val =~ tr/ /./; $val',
    },
    VFOV => {
        Name      => 'FieldOfView',
        PrintConv => {
            W => 'Wide',
            S => 'Super View',
            L => 'Linear',
        },
    },
    VFPS => { Name => 'VideoFrameRate', PrintConv => '$val=~s( )(/);$val' },
    VFRH => {
        Name       => 'VisualFlightRulesHUD',
        BinaryData => 1,
    },
    VRES => { Name => 'VideoFrameSize', PrintConv => '$val=~s/ /x/;$val' },
    WBAL => 'ColorTemperatures',
    WRGB => {
        Name   => 'WhiteBalanceRGB',
        Binary => 1,
    },
    ZFOV => 'DiagonalFieldOfView',
    ZMPL => 'ZoomScaleNormalization',
    MUID => {
        Name      => 'MediaUniqueID',
        PrintConv => q{
            my @a = split ' ', $val;
            $_ = sprintf('%.8x',$_) foreach @a;
            return join('', @a);
        },
    },
    MTRX => 'AccelerometerMatrix',
    ORIN => 'InputOrientation',
    ORIO => 'OutputOrientation',
    UNIF => 'InputUniformity',
    SROT => 'SensorReadoutTime',
    CORI =>
      { Name => 'CameraOrientation', Binary => 1, Notes => 'quaternions 0-1' },
    AALP => { Name => 'AudioLevel', Notes => 'dBFS' },
    GPSA => 'GPSAltitudeSystem',
    GRAV => { Name => 'GravityVector', Binary => 1 },
    HUES => 'PredominantHue',
    IORI =>
      { Name => 'ImageOrientation', Binary => 1, Notes => 'quaternions 0-1' },
    MWET => 'MicrophoneWet',
    SCEN => 'SceneClassification',
    WNDM => 'WindProcessing',
    YAVG => 'LumaAverage',
);

%Image::ExifTool::GoPro::GPS5 = (
    PROCESS_PROC => \&ProcessString,
    GROUPS       => { 1      => 'GoPro', 2        => 'Location' },
    VARS         => { ID_FMT => 'dec',   ID_LABEL => 'Index' },
    0            => {
        Name      => 'GPSLatitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    1 => {
        Name      => 'GPSLongitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    2 => {
        Name      => 'GPSAltitude',
        PrintConv => '"$val m"',
    },
    3 => {
        Name      => 'GPSSpeed',
        Notes     => 'stored as m/s but converted to km/h when extracted',
        ValueConv => '$val * 3.6',
    },
    4 => {
        Name      => 'GPSSpeed3D',
        Notes     => 'stored as m/s but converted to km/h when extracted',
        ValueConv => '$val * 3.6',
    },
);

%Image::ExifTool::GoPro::GPS9 = (
    PROCESS_PROC => \&ProcessString,
    GROUPS       => { 1      => 'GoPro', 2        => 'Location' },
    VARS         => { ID_FMT => 'dec',   ID_LABEL => 'Index' },
    0            => {
        Name      => 'GPSLatitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    1 => {
        Name      => 'GPSLongitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    2 => {
        Name      => 'GPSAltitude',
        PrintConv => '"$val m"',
    },
    3 => {
        Name      => 'GPSSpeed',
        Notes     => 'stored as m/s but converted to km/h when extracted',
        ValueConv => '$val * 3.6',
    },
    4 => {
        Name      => 'GPSSpeed3D',
        Notes     => 'stored as m/s but converted to km/h when extracted',
        ValueConv => '$val * 3.6',
    },
    5 => {
        Name    => 'GPSDays',
        RawConv => '$$self{GPSDays} = $val; undef',
        Hidden  => 1,
    },
    6 => {
        Name   => 'GPSDateTime',
        Groups => { 2 => 'Time' },
        RawConv =>
'ConvertUnixTime(($$self{GPSDays} + 10957) * 24 * 3600 + $val, undef, 3)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    7 => 'GPSDOP',
    8 => {
        Name      => 'GPSMeasureMode',
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
);

%Image::ExifTool::GoPro::GPRI = (
    PROCESS_PROC => \&ProcessString,
    GROUPS       => { 1      => 'GoPro', 2        => 'Location' },
    VARS         => { ID_FMT => 'dec',   ID_LABEL => 'Index' },
    0            => {
        Name      => 'GPSDateTimeRaw',
        Groups    => { 2 => 'Time' },
        ValueConv => \&ConvertSystemTime,
        PrintConv => '$self->ConvertDateTime($val)',
    },
    1 => {
        Name      => 'GPSLatitudeRaw',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    2 => {
        Name      => 'GPSLongitudeRaw',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    3 => {
        Name      => 'GPSAltitudeRaw',
        PrintConv => '"$val m"',
    },
    4 => {
        Name      => 'GPRI_Unknown4',
        Unknown   => 1,
        Hidden    => 1,
        PrintConv => '"$val m"'
    },
    5 => {
        Name      => 'GPRI_Unknown5',
        Unknown   => 1,
        Hidden    => 1,
        PrintConv => '"$val m"'
    },
    6 => 'GPSSpeedRaw',
    7 => 'GPSTrackRaw',
    8 => { Name => 'GPRI_Unknown8', Unknown => 1, Hidden => 1 },
    9 => { Name => 'GPRI_Unknown9', Unknown => 1, Hidden => 1 },
);

%Image::ExifTool::GoPro::GLPI = (
    PROCESS_PROC => \&ProcessString,
    GROUPS       => { 1      => 'GoPro', 2        => 'Location' },
    VARS         => { ID_FMT => 'dec',   ID_LABEL => 'Index' },
    0            => {
        Name      => 'GPSDateTime',
        Groups    => { 2 => 'Time' },
        ValueConv => \&ConvertSystemTime,
        PrintConv => '$self->ConvertDateTime($val)',
    },
    1 => {
        Name      => 'GPSLatitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    2 => {
        Name      => 'GPSLongitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    3 => {
        Name      => 'GPSAltitude',
        PrintConv => '"$val m"',
    },
    4 => {
        Name      => 'GLPI_Unknown4',
        Unknown   => 1,
        Hidden    => 1,
        PrintConv => '"$val m"'
    },
    5 => { Name => 'GPSSpeedX', PrintConv => '"$val m/s"' },
    6 => { Name => 'GPSSpeedY', PrintConv => '"$val m/s"' },
    7 => { Name => 'GPSSpeedZ', PrintConv => '"$val m/s"' },
    8 => { Name => 'GPSTrack' },
);

%Image::ExifTool::GoPro::KBAT = (
    PROCESS_PROC => \&ProcessString,
    GROUPS       => { 1      => 'GoPro', 2        => 'Camera' },
    VARS         => { ID_FMT => 'dec',   ID_LABEL => 'Index' },
    NOTES        => 'Battery status information found in GoPro Karma videos.',
    0            => { Name => 'BatteryCurrent',  PrintConv => '"$val A"' },
    1            => { Name => 'BatteryCapacity', PrintConv => '"$val Ah"' },
    2            => {
        Name      => 'KBAT_Unknown2',
        PrintConv => '"$val J"',
        Unknown   => 1,
        Hidden    => 1
    },
    3 => { Name => 'BatteryTemperature', PrintConv => '"$val C"' },
    4 => { Name => 'BatteryVoltage1',    PrintConv => '"$val V"' },
    5 => { Name => 'BatteryVoltage2',    PrintConv => '"$val V"' },
    6 => { Name => 'BatteryVoltage3',    PrintConv => '"$val V"' },
    7 => { Name => 'BatteryVoltage4',    PrintConv => '"$val V"' },
    8 => {
        Name      => 'BatteryTime',
        PrintConv => 'ConvertDuration(int($val + 0.5))'
    },
    9 => {
        Name      => 'KBAT_Unknown9',
        PrintConv => '"$val %"',
        Unknown   => 1,
        Hidden    => 1,
    },
    10 => { Name => 'KBAT_Unknown10', Unknown   => 1, Hidden => 1 },
    11 => { Name => 'KBAT_Unknown11', Unknown   => 1, Hidden => 1 },
    12 => { Name => 'KBAT_Unknown12', Unknown   => 1, Hidden => 1 },
    13 => { Name => 'KBAT_Unknown13', Unknown   => 1, Hidden => 1 },
    14 => { Name => 'BatteryLevel',   PrintConv => '"$val %"' },
);

%Image::ExifTool::GoPro::fdsc = (
    GROUPS       => { 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES        => q{
        Tags extracted from the MP4 "fdsc" timed metadata when the L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded>
        (-ee) option is used.
    },
    0x08 => { Name => 'FirmwareVersion',   Format => 'string[15]' },
    0x17 => { Name => 'SerialNumber',      Format => 'string[16]' },
    0x57 => { Name => 'OtherSerialNumber', Format => 'string[15]' },
    0x66 => {
        Name        => 'Model',
        Description => 'Camera Model Name',
        Format      => 'string[16]',
    },
);

sub ConvertSystemTime($$) {
    my ( $val, $et ) = @_;
    my $s = $$et{SystemTimeList} or return '<uncalibrated>';
    unless ( $$et{SystemTimeListSorted} ) {
        $s = $$et{SystemTimeList} = [ sort { $$a[0] <=> $$b[0] } @$s ];
        $$et{SystemTimeListSorted} = 1;
    }
    my ( $i, $j ) = ( 0, $#$s );
    while ( $j - $i > 1 ) {
        my $t = int( ( $i + $j ) / 2 );
        ( $val < $$s[$t][0] ? $j : $i ) = $t;
    }
    if ( $i == $j or $$s[$j][0] == $$s[$i][0] ) {
        $val = $$s[$i][1];
    }
    else {
        $val =
          $$s[$i][1] +
          ( $$s[$j][1] - $$s[$i][1] ) *
          ( $val - $$s[$i][0] ) /
          ( $$s[$j][0] - $$s[$i][0] );
    }
    my ( $t, $f ) = ( "$val" =~ /^(\d+)(\.\d+)/ );
    return Image::ExifTool::ConvertUnixTime( $t, $$et{OPTIONS}{QuickTimeUTC} )
      . $f;
}

sub ScaleValues($$) {
    my ( $val, $scl ) = @_;
    return unless $val and $scl;
    my @scl = split ' ', $scl or return;
    my @scaled;
    my $v = ( ref $val eq 'ARRAY' ) ? $val : [$val];
    foreach $val (@$v) {
        my @a = split ' ', $val;
        $a[$_] /= $scl[ $_ % @scl ] foreach 0 .. $#a;
        push @scaled, join( ' ', @a );
    }
    $_[0] = @scaled > 1 ? \@scaled : $scaled[0];
}

sub AddUnits($$$) {
    my ( $et, $val, $tag ) = @_;
    if ( $et and $$et{TAG_EXTRA}{$tag}{Units} ) {
        my $u = $$et{TAG_EXTRA}{$tag}{Units};
        $u = [$u] unless ref $u eq 'ARRAY';
        my @a = split ' ', $val;
        if ( @$u == @a ) {
            my $i;
            for ( $i = 0 ; $i < @a ; ++$i ) {
                $a[$i] .= ' ' . $$u[$i] if $$u[$i];
            }
            $val = join ' ', @a;
        }
    }
    return $val;
}

sub ProcessString($$$) {
    my ( $et, $dirInfo, $tagTablePtr ) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my @list   = ref $$dataPt eq 'ARRAY' ? @{$$dataPt} : ($$dataPt);
    my ( $string, $val );
    $et->VerboseDir('GoPro structure');
    my $docNum = $$et{DOC_NUM};
    my $subDoc = 0;
    foreach $string (@list) {
        my @val = split ' ', $string;
        my $i   = 0;
        foreach $val (@val) {
            $et->HandleTag( $tagTablePtr, $i, $val );
            next if $$tagTablePtr{ ++$i };
            $i = 0;
            ++$subDoc;
            $$et{DOC_NUM} = "$docNum-$subDoc";
        }
        if ($i) {
            ++$subDoc;
            $$et{DOC_NUM} = "$docNum-$subDoc";
        }
    }
    $$et{DOC_NUM} = $docNum;
    return 1;
}

sub ProcessGP6($$) {
    my ( $et, $dirInfo ) = @_;
    my $raf = $$dirInfo{RAF};
    my $len = $$dirInfo{DirLen};
    my $buff;
    while ( $len > 16 ) {
        $raf->Read( $buff, 16 ) == 16 or last;
        my ( $tag, $size ) = unpack( 'a4N', $buff );
        last if $size + 16 > $len           or $buff !~ /^GP..\0/s;
        $raf->Read( $buff, $size ) == $size or last;
        if ( $buff =~ /^DEVC/ ) {
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            my $tagTbl = GetTagTable('Image::ExifTool::GoPro::GPMF');
            ProcessGoPro( $et,
                { DataPt => \$buff, DataPos => $raf->Tell() - $size },
                $tagTbl );
        }
        $len -= $size + 16;
    }
    delete $$et{DOC_NUM};
    return $$dirInfo{DirLen} - $len;
}

sub ProcessGoPro($$$) {
    my ( $et, $dirInfo, $tagTablePtr ) = @_;
    my $dataPt  = $$dirInfo{DataPt};
    my $base    = $$dirInfo{Base};
    my $pos     = $$dirInfo{DirStart} || 0;
    my $dirEnd  = $pos + ( $$dirInfo{DirLen} || ( length($$dataPt) - $pos ) );
    my $verbose = $et->Options('Verbose');
    my $unknown = $verbose || $et->Options('Unknown');
    my ( $size, $type, $unit, $scal, $setGroup0 );

    $et->VerboseDir( $$dirInfo{DirName} || 'GPMF', undef, $dirEnd - $pos )
      if $verbose;
    $$et{FoundEmbedded} = 1;
    if ($pos) {
        my $parent = $$dirInfo{Parent};
        $setGroup0 = $$et{SET_GROUP0} = 'APP6' if $parent and $parent eq 'APP6';
    }
    else {
        $setGroup0 = $$et{SET_GROUP0} = 'QuickTime' unless $$et{SET_GROUP1};
    }

    for ( ; $pos + 8 <= $dirEnd ; $pos += ( $size + 3 ) & 0xfffffffc ) {
        my ( $tag, $fmt, $len, $count ) = unpack( "x${pos}a4CCn", $$dataPt );
        if ( $tag =~ /[^-_a-zA-Z0-9 ]/ ) {
            $et->Warn('Unrecognized GoPro record') unless $tag eq "\0\0\0\0";
            last;
        }
        $size = $len * $count;
        $pos += 8;
        if ( $pos + $size > $dirEnd ) {
            $et->Warn('Truncated GoPro record');
            last;
        }
        my $tagInfo = $et->GetTagInfo( $tagTablePtr, $tag );
        last if $tag eq "\0\0\0\0";
        next unless $size or $verbose;
        my $format = $goProFmt{$fmt} || 'undef';
        my ( $val, $i, $j, $p, @v );
        if ( $fmt == 0x3f and defined $type ) {
            for ( $i = 0 ; $i < $count ; ++$i ) {
                my ( @s, $l );
                for ( $j = 0, $p = 0 ; $j < length($type) ; ++$j, $p += $l ) {
                    my $b = Get8u( \$type, $j );
                    my $f = $goProFmt{$b} or last;
                    $l = $goProSize{$b} || Image::ExifTool::FormatSize($f)
                      or last;
                    last if $p + $l > $len;
                    my $s =
                      ReadValue( $dataPt, $pos + $i * $len + $p, $f, undef,
                        $l );
                    last unless defined $s;
                    push @s, $s;
                }
                push @v, join ' ', @s if @s;
            }
            $val = @v > 1 ? \@v : $v[0];
        }
        elsif ( ( $format eq 'undef' or $format eq 'string' )
            and $count > 1
            and $len > 1 )
        {
            my $a = $format eq 'undef' ? 'a' : 'A';
            $val = [ unpack( "x${pos}" . ( "$a$len" x $count ), $$dataPt ) ];
        }
        else {
            $val = ReadValue( $dataPt, $pos, $format, undef, $size );
        }
        $type = $val if $tag eq 'TYPE';
        $unit = $val if $tag eq 'UNIT' or $tag eq 'SIUN';
        $scal = $val if $tag eq 'SCAL';

        unless ($tagInfo) {
            next unless $unknown;
            my $name = Image::ExifTool::QuickTime::PrintableTagID($tag);
            $tagInfo = {
                Name        => "GoPro_$name",
                Description => "GoPro $name",
                Unknown     => 1
            };
            $$tagInfo{SubDirectory} =
              { TagTable => 'Image::ExifTool::GoPro::GPMF' }
              if not $fmt;
            AddTagToTable( $tagTablePtr, $tag, $tagInfo );
        }
        ScaleValues( $val, $scal )
          if $scal
          and $tag ne 'SCAL'
          and $pos + $size + 3 >= $dirEnd;
        my $key = $et->HandleTag(
            $tagTablePtr, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Base    => $base,
            Start   => $pos,
            Size    => $size,
            TagInfo => $tagInfo,
            Format  => $format,
            Extra   => $verbose
            ? ", type='"
              . ( $fmt ? chr($fmt) : '\0' )
              . "' size=$len count=$count"
            : undef,
        );
        $$et{TAG_EXTRA}{$key}{Units} = $unit if $$tagInfo{AddUnits} and $key;
    }
    delete $$et{SET_GROUP0} if $setGroup0;
    return 1;
}

1;

__END__


