
package Image::ExifTool::Google;

use strict;
use vars            qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;

$VERSION = '1.01';

sub ProcessHDRP($$$);

my @formatName = ( undef, 'string', 'int16s', undef, 'int32s' );

my %sPose = (
    STRUCT_NAME => 'Google Pose',
    NAMESPACE   => { Pose     => 'http://ns.google.com/photos/dd/1.0/pose/' },
    PositionX   => { Writable => 'real', Groups => { 2 => 'Location' } },
    PositionY   => { Writable => 'real', Groups => { 2 => 'Location' } },
    PositionZ   => { Writable => 'real', Groups => { 2 => 'Location' } },
    RotationX   => { Writable => 'real', Groups => { 2 => 'Location' } },
    RotationY   => { Writable => 'real', Groups => { 2 => 'Location' } },
    RotationZ   => { Writable => 'real', Groups => { 2 => 'Location' } },
    RotationW   => { Writable => 'real', Groups => { 2 => 'Location' } },
    Timestamp   => {
        Name         => 'TimeStamp',
        Writable     => 'integer',
        Shift        => 'Time',
        Groups       => { 2 => 'Time' },
        ValueConv    => 'ConvertUnixTime($val / 1000, 1, 3)',
        ValueConvInv => 'int(GetUnixTime($val, 1) * 1000)',
        PrintConv    => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
    },
);
my %sEarthPose = (
    STRUCT_NAME => 'Google EarthPose',
    NAMESPACE   =>
      { EarthPose => 'http://ns.google.com/photos/dd/1.0/earthpose/' },
    Latitude => {
        Writable     => 'real',
        Groups       => { 2 => 'Location' },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        ValueConvInv => '$val',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lat")',
    },
    Longitude => {
        Writable     => 'real',
        Groups       => { 2 => 'Location' },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        ValueConvInv => '$val',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lon")',
    },
    Altitude => {
        Writable     => 'real',
        Groups       => { 2 => 'Location' },
        PrintConv    => '"$val m"',
        PrintConvInv => '$val=~s/\s*m$//;$val',
    },
    RotationX => { Writable => 'real', Groups => { 2 => 'Location' } },
    RotationY => { Writable => 'real', Groups => { 2 => 'Location' } },
    RotationZ => { Writable => 'real', Groups => { 2 => 'Location' } },
    RotationW => { Writable => 'real', Groups => { 2 => 'Location' } },
    Timestamp => {
        Name         => 'TimeStamp',
        Writable     => 'integer',
        Shift        => 'Time',
        Groups       => { 2 => 'Time' },
        ValueConv    => 'ConvertUnixTime($val / 1000, 1, 3)',
        ValueConvInv => 'int(GetUnixTime($val, 1) * 1000)',
        PrintConv    => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
    },
);
my %sVendorInfo = (
    STRUCT_NAME => 'Google VendorInfo',
    NAMESPACE   =>
      { VendorInfo => 'http://ns.google.com/photos/dd/1.0/vendorinfo/' },
    Model        => {},
    Manufacturer => {},
    Notes        => {},
);
my %sAppInfo = (
    STRUCT_NAME => 'Google AppInfo',
    NAMESPACE   => { AppInfo => 'http://ns.google.com/photos/dd/1.0/appinfo/' },
    Application => {},
    Version     => {},
    ItemURI     => {},
);

%Image::ExifTool::Google::GAudio = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS    => { 0 => 'XMP', 1 => 'XMP-GAudio', 2 => 'Audio' },
    NAMESPACE => 'GAudio',
    Data      => {
        Name         => 'AudioData',
        ValueConv    => 'Image::ExifTool::XMP::DecodeBase64($val)',
        ValueConvInv => 'Image::ExifTool::XMP::EncodeBase64($val)',
    },
    Mime => { Name => 'AudioMimeType' },
);

%Image::ExifTool::Google::GImage = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS    => { 0 => 'XMP', 1 => 'XMP-GImage', 2 => 'Image' },
    NAMESPACE => 'GImage',
    Data      => {
        Name         => 'ImageData',
        ValueConv    => 'Image::ExifTool::XMP::DecodeBase64($val)',
        ValueConvInv => 'Image::ExifTool::XMP::EncodeBase64($val)',
    },
    Mime => { Name => 'ImageMimeType' },
);

%Image::ExifTool::Google::GPano = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS    => { 0 => 'XMP', 1 => 'XMP-GPano', 2 => 'Image' },
    NAMESPACE => 'GPano',
    NOTES     => q{
        Panorama tags written by Google Photosphere. See
        L<https://developers.google.com/streetview/spherical-metadata> for the
        specification.
    },
    UsePanoramaViewer           => { Writable => 'boolean' },
    CaptureSoftware             => {},
    StitchingSoftware           => {},
    ProjectionType              => {},
    PoseHeadingDegrees          => { Writable => 'real' },
    PosePitchDegrees            => { Writable => 'real' },
    PoseRollDegrees             => { Writable => 'real' },
    InitialViewHeadingDegrees   => { Writable => 'real' },
    InitialViewPitchDegrees     => { Writable => 'real' },
    InitialViewRollDegrees      => { Writable => 'real' },
    InitialHorizontalFOVDegrees => { Writable => 'real' },
    InitialVerticalFOVDegrees   => { Writable => 'real' },
    FirstPhotoDate              =>
      { %Image::ExifTool::XMP::dateTimeInfo, Groups => { 2 => 'Time' } },
    LastPhotoDate =>
      { %Image::ExifTool::XMP::dateTimeInfo, Groups => { 2 => 'Time' } },
    SourcePhotosCount            => { Writable => 'integer' },
    ExposureLockUsed             => { Writable => 'boolean' },
    CroppedAreaImageWidthPixels  => { Writable => 'real' },
    CroppedAreaImageHeightPixels => { Writable => 'real' },
    FullPanoWidthPixels          => { Writable => 'real' },
    FullPanoHeightPixels         => { Writable => 'real' },
    CroppedAreaLeftPixels        => { Writable => 'real' },
    CroppedAreaTopPixels         => { Writable => 'real' },
    InitialCameraDolly           => { Writable => 'real' },
    LargestValidInteriorRectLeft   => { Writable => 'real' },
    LargestValidInteriorRectTop    => { Writable => 'real' },
    LargestValidInteriorRectWidth  => { Writable => 'real' },
    LargestValidInteriorRectHeight => { Writable => 'real' },
);

%Image::ExifTool::Google::GSpherical = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS      => { 0 => 'XMP', 1 => 'XMP-GSpherical', 2 => 'Image' },
    WRITE_GROUP => 'GSpherical',
    NAMESPACE   => 'GSpherical',
    AVOID       => 1,
    NOTES       => q{
        Not actually XMP.  These RDF/XML tags are used in Google spherical MP4
        videos.  These tags are written into the video track of MOV/MP4 files, and
        not at the top level like other XMP tags.  See
        L<https://github.com/google/spatial-media/blob/master/docs/spherical-video-rfc.md>
        for the specification.
    },
    Spherical                 => { Writable => 'boolean' },
    Stitched                  => { Writable => 'boolean' },
    StitchingSoftware         => {},
    ProjectionType            => {},
    StereoMode                => {},
    SourceCount               => { Writable => 'integer' },
    InitialViewHeadingDegrees => { Writable => 'real' },
    InitialViewPitchDegrees   => { Writable => 'real' },
    InitialViewRollDegrees    => { Writable => 'real' },
    Timestamp                 => {
        Name         => 'TimeStamp',
        Groups       => { 2 => 'Time' },
        Writable     => 'integer',
        Shift        => 'Time',
        ValueConv    => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv    => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    FullPanoWidthPixels          => { Writable => 'integer' },
    FullPanoHeightPixels         => { Writable => 'integer' },
    CroppedAreaImageWidthPixels  => { Writable => 'integer' },
    CroppedAreaImageHeightPixels => { Writable => 'integer' },
    CroppedAreaLeftPixels        => { Writable => 'integer' },
    CroppedAreaTopPixels         => { Writable => 'integer' },
);

%Image::ExifTool::Google::GDepth = (
    GROUPS    => { 0 => 'XMP', 1 => 'XMP-GDepth', 2 => 'Image' },
    NAMESPACE => 'GDepth',
    AVOID     => 1,
    NOTES     => q{
        Google depthmap information. See
        L<https://developers.google.com/depthmap-metadata/> for the specification.
    },
    WRITABLE => 'string',
    PRIORITY => 0,
    Format   => {
        PrintConv => {
            RangeInverse => 'RangeInverse',
            RangeLinear  => 'RangeLinear',
        },
    },
    Near => { Writable => 'real' },
    Far  => { Writable => 'real' },
    Mime => {},
    Data => {
        Name         => 'DepthImage',
        ValueConv    => 'Image::ExifTool::XMP::DecodeBase64($val)',
        ValueConvInv => 'Image::ExifTool::XMP::EncodeBase64($val)',
    },
    Units       => {},
    MeasureType => {
        PrintConv => {
            OpticalAxis => 'OpticalAxis',
            OpticalRay  => 'OpticalRay',
        },
    },
    ConfidenceMime => {},
    Confidence     => {
        ValueConv    => 'Image::ExifTool::XMP::DecodeBase64($val)',
        ValueConvInv => 'Image::ExifTool::XMP::EncodeBase64($val)',
    },
    Manufacturer => {},
    Model        => {},
    Software     => {},
    ImageWidth   => { Writable => 'real' },
    ImageHeight  => { Writable => 'real' },
);

%Image::ExifTool::Google::GFocus = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS         => { 0 => 'XMP', 1 => 'XMP-GFocus', 2 => 'Image' },
    NAMESPACE      => 'GFocus',
    NOTES          => 'Focus information found in Google depthmap images.',
    BlurAtInfinity => { Writable => 'real' },
    FocalDistance  => { Writable => 'real' },
    FocalPointX    => { Writable => 'real' },
    FocalPointY    => { Writable => 'real' },
);

%Image::ExifTool::Google::GCamera = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS          => { 0 => 'XMP', 1 => 'XMP-GCamera', 2 => 'Camera' },
    NAMESPACE       => 'GCamera',
    NOTES           => 'Camera information found in Google panorama images.',
    BurstID         => {},
    BurstPrimary    => {},
    PortraitNote    => {},
    PortraitRequest => {
        Writable     => 'string',
        Binary       => 1,
        SubDirectory =>
          { TagTable => 'Image::ExifTool::Google::HDRPMakerNote' },
    },
    PortraitVersion        => {},
    SpecialTypeID          => { List => 'Bag' },
    PortraitNote           => {},
    DisableAutoCreation    => { List => 'Bag' },
    DisableSuggestedAction => { List => 'Bag' },
    hdrp_makernote         => {
        Name         => 'HDRPMakerNote',
        Writable     => 'string',
        Binary       => 1,
        SubDirectory =>
          { TagTable => 'Image::ExifTool::Google::HDRPMakerNote' },
    },
    MicroVideo                        => { Writable => 'integer' },
    MicroVideoVersion                 => { Writable => 'integer' },
    MicroVideoOffset                  => { Writable => 'integer' },
    MicroVideoPresentationTimestampUs => { Writable => 'integer' },
    shot_log_data                     => {
        Name         => 'ShotLogData',
        Writable     => 'string',
        IsProtobuf   => 1,
        Binary       => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Google::ShotLogData' },
    },
    HdrPlusMakernote => {
        Name         => 'HDRPlusMakerNote',
        Writable     => 'string',
        Binary       => 1,
        SubDirectory =>
          { TagTable => 'Image::ExifTool::Google::HDRPlusMakerNote' },
    },
    MotionPhoto                        => { Writable => 'integer' },
    MotionPhotoVersion                 => { Writable => 'integer' },
    MotionPhotoPresentationTimestampUs => { Writable => 'integer' },
);

%Image::ExifTool::Google::GCreations = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS        => { 0 => 'XMP', 1 => 'XMP-GCreations', 2 => 'Camera' },
    NAMESPACE     => 'GCreations',
    NOTES         => 'Google creations tags.',
    CameraBurstID => {},
    Type          => { Avoid => 1 },
);

%Image::ExifTool::Google::Device = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS    => { 0      => 'XMP', 1 => 'XMP-Device', 2 => 'Camera' },
    NAMESPACE => { Device => 'http://ns.google.com/photos/dd/1.0/device/' },
    NOTES     => q{
        Google depth-map Device tags.  See
        L<https://developer.android.com/training/camera2/Dynamic-depth-v1.0.pdf> for
        the specification.
    },
    Container => {
        Struct => {
            STRUCT_NAME => 'Google DeviceContainer',
            NAMESPACE   =>
              { Container => 'http://ns.google.com/photos/dd/1.0/container/' },
            Directory => {
                List   => 'Seq',
                Struct => {
                    STRUCT_NAME => 'Google DeviceDirectory',
                    NAMESPACE   => {
                        Container =>
                          'http://ns.google.com/photos/dd/1.0/container/'
                    },
                    Item => {
                        Struct => {
                            STRUCT_NAME => 'Google DeviceItem',
                            NAMESPACE   => {
                                Item =>
                                  'http://ns.google.com/photos/dd/1.0/item/'
                            },
                            Mime => {
                                RawConv => '$$self{ProcessGoogleTrailer} = $val'
                            },
                            Length  => { Writable => 'integer' },
                            Padding => { Writable => 'integer' },
                            DataURI => {},
                        },
                    },
                },
            }
        },
    },
    Profiles => {
        List     => 'Seq',
        FlatName => '',
        Struct   => {
            STRUCT_NAME => 'Google DeviceProfiles',
            NAMESPACE   =>
              { Device => 'http://ns.google.com/photos/dd/1.0/device/' },
            Profile => {
                Struct => {
                    STRUCT_NAME => 'Google DeviceProfile',
                    NAMESPACE   => {
                        Profile => 'http://ns.google.com/photos/dd/1.0/profile/'
                    },
                    CameraIndices => { List => 'Seq', Writable => 'integer' },
                    Type          => {},
                },
            },
        },
    },
    Cameras => {
        List     => 'Seq',
        FlatName => '',
        Struct   => {
            STRUCT_NAME => 'Google DeviceCameras',
            NAMESPACE   =>
              { Device => 'http://ns.google.com/photos/dd/1.0/device/' },
            Camera => {
                Struct => {
                    STRUCT_NAME => 'Google DeviceCamera',
                    NAMESPACE   => {
                        Camera => 'http://ns.google.com/photos/dd/1.0/camera/'
                    },
                    DepthMap => {
                        Struct => {
                            STRUCT_NAME => 'Google DeviceDepthMap',
                            NAMESPACE   => {
                                DepthMap =>
                                  'http://ns.google.com/photos/dd/1.0/depthmap/'
                            },
                            ConfidenceURI        => {},
                            DepthURI             => {},
                            Far                  => { Writable => 'real' },
                            Format               => {},
                            ItemSemantic         => {},
                            MeasureType          => {},
                            Near                 => { Writable => 'real' },
                            Units                => {},
                            Software             => {},
                            FocalTableEntryCount => { Writable => 'integer' },
                            FocalTable           => {},
                        },
                    },
                    Image => {
                        Struct => {
                            STRUCT_NAME => 'Google DeviceImage',
                            NAMESPACE   => {
                                Image =>
                                  'http://ns.google.com/photos/dd/1.0/image/'
                            },
                            ItemSemantic => {},
                            ItemURI      => {},
                        },
                    },
                    ImagingModel => {
                        Struct => {
                            STRUCT_NAME => 'Google DeviceImagingModel',
                            NAMESPACE   => {
                                ImagingModel =>
'http://ns.google.com/photos/dd/1.0/imagingmodel/'
                            },
                            Distortion       => {},
                            DistortionCount  => { Writable => 'integer' },
                            FocalLengthX     => { Writable => 'real' },
                            FocalLengthY     => { Writable => 'real' },
                            ImageHeight      => { Writable => 'integer' },
                            ImageWidth       => { Writable => 'integer' },
                            PixelAspectRatio => { Writable => 'real' },
                            PrincipalPointX  => { Writable => 'real' },
                            PrincipalPointY  => { Writable => 'real' },
                            Skew             => { Writable => 'real' },
                        },
                    },
                    PointCloud => {
                        Struct => {
                            STRUCT_NAME => 'Google DevicePointCloud',
                            NAMESPACE   => {
                                PointCloud =>
'http://ns.google.com/photos/dd/1.0/pointcloud/'
                            },
                            PointCloud => { Writable => 'integer' },
                            Points     => {},
                            Metric     => { Writable => 'boolean' },
                        },
                    },
                    Pose          => { Struct => \%sPose },
                    LightEstimate => {
                        Struct => {
                            STRUCT_NAME => 'Google DeviceLightEstimate',
                            NAMESPACE   => {
                                LightEstimate =>
'http://ns.google.com/photos/dd/1.0/lightestimate/'
                            },
                            ColorCorrectionR => { Writable => 'real' },
                            ColorCorrectionG => { Writable => 'real' },
                            ColorCorrectionB => { Writable => 'real' },
                            PixelIntensity   => { Writable => 'real' },
                        },
                    },
                    VendorInfo => { Struct => \%sVendorInfo },
                    AppInfo    => { Struct => \%sAppInfo },
                    Trait      => {},
                },
            },
        },
    },
    VendorInfo => { Struct => \%sVendorInfo },
    AppInfo    => { Struct => \%sAppInfo },
    EarthPos   => { Struct => \%sEarthPose },
    Pose       => { Struct => \%sPose },
    Planes     => {
        List     => 'Seq',
        FlatName => '',
        Struct   => {
            STRUCT_NAME => 'Google DevicePlanes',
            NAMESPACE   =>
              { Device => 'http://ns.google.com/photos/dd/1.0/device/' },
            Plane => {
                Struct => {
                    STRUCT_NAME => 'Google DevicePlane',
                    NAMESPACE   =>
                      { Plane => 'http://ns.google.com/photos/dd/1.0/plane/' },
                    Pose                => { Struct   => \%sPose },
                    ExtentX             => { Writable => 'real' },
                    ExtentZ             => { Writable => 'real' },
                    BoundaryVertexCount => { Writable => 'integer' },
                    Boundary            => {},
                },
            },
        },
    },
);

%Image::ExifTool::Google::GContainer = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS    => { 0 => 'XMP', 1 => 'XMP-GContainer', 2 => 'Image' },
    NAMESPACE => 'GContainer',
    NOTES     => q{
        Google Container namespace.  ExifTool uses the prefix 'GContainer' instead
        of 'Container' to avoid a conflict with the Google Device Container
        namespace.
    },
    Directory => {
        Name     => 'ContainerDirectory',
        FlatName => 'Directory',
        List     => 'Seq',
        Struct   => {
            STRUCT_NAME => 'Google Directory',
            Item        => {
                Namespace => 'GContainer',
                Struct    => {
                    STRUCT_NAME => 'Google Item',
                    NAMESPACE => {
                        GItem =>
                          'http://ns.google.com/photos/1.0/container/item/'
                    },
                    Mime =>
                      { RawConv => '$$self{ProcessGoogleTrailer} = $val' },
                    Semantic => {},
                    Length   => { Writable => 'integer' },
                    Label    => {},
                    Padding  => { Writable => 'integer' },
                    URI      => {},
                },
            },
        },
    },
);

%Image::ExifTool::Google::HDRPlusMakerNote = (
    GROUPS       => { 0 => 'MakerNotes', 2 => 'Image' },
    TAG_PREFIX   => 'HDRPlusMakerNote',
    PROCESS_PROC => \&ProcessHDRP,
    VARS         => {
        ID_FMT    => 'str',
        SORT_PROC => sub {
            my ( $a, $b ) = @_;
            $a =~ s/(\d+)/sprintf("%.3d",$1)/eg;
            $b =~ s/(\d+)/sprintf("%.3d",$1)/eg;
            return $a cmp $b;
        },
    },
    NOTES => q{
        Google protobuf-format HDR-Plus maker notes.  Tag ID's are hierarchical
        protobuf field numbers.  Stored as base64-encoded, encrypted and gzipped
        Protobuf data.  Much of this metadata is still unknown, but is extracted
        using the Unknown option.
    },
    '1-1' => 'ImageName',
    '1-2' => { Name => 'ImageData',   Format => 'undef', Binary => 1 },
    '2'   => { Name => 'TimeLogText', Binary => 1 },
    '3'   => { Name => 'SummaryText', Binary => 1 },
    '9-3' => { Name => 'FrameCount',  Format => 'unsigned' },
    '9-36-1' => {
        Name      => 'CreateDate',
        Groups    => { 2 => 'Time' },
        Format    => 'unsigned',
        Priority  => 0,
        ValueConv => 'ConvertUnixTime($val, 1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '12-1' => { Name => 'DeviceMake',             Groups => { 2 => 'Device' } },
    '12-2' => { Name => 'DeviceModel',            Groups => { 2 => 'Device' } },
    '12-3' => { Name => 'DeviceCodename',         Groups => { 2 => 'Device' } },
    '12-4' => { Name => 'DeviceHardwareRevision', Groups => { 2 => 'Device' } },
    '12-6' => { Name => 'HDRPSoftware',           Groups => { 2 => 'Device' } },
    '12-7' => { Name => 'AndroidRelease',         Groups => { 2 => 'Device' } },
    '12-8' => {
        Name      => 'SoftwareDate',
        Groups    => { 2 => 'Time' },
        Format    => 'unsigned',
        ValueConv => 'ConvertUnixTime($val / 1000, 1, 3)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '12-9'    => { Name => 'Application', Groups => { 2 => 'Device' } },
    '12-10'   => { Name => 'AppVersion',  Groups => { 2 => 'Device' } },
    '12-12-1' => {
        Name      => 'ExposureTimeMin',
        Groups    => { 2 => 'Camera' },
        Format    => 'float',
        ValueConv => '$val / 1000',
    },
    '12-12-2' => {
        Name      => 'ExposureTimeMax',
        Groups    => { 2 => 'Camera' },
        Format    => 'float',
        ValueConv => '$val / 1000',
    },
    '12-13-1' =>
      { Name => 'ISOMin', Format => 'float', Groups => { 2 => 'Camera' } },
    '12-13-2' =>
      { Name => 'ISOMax', Format => 'float', Groups => { 2 => 'Camera' } },
    '12-14' => {
        Name   => 'MaxAnalogISO',
        Format => 'float',
        Groups => { 2 => 'Camera' }
    },
);

%Image::ExifTool::Google::ShotLogData = (
    GROUPS       => { 0 => 'MakerNotes', 2 => 'Image' },
    TAG_PREFIX   => 'ShotLogData',
    PROCESS_PROC => \&ProcessHDRP,
    VARS         => { ID_FMT => 'str' },
    NOTES => 'Stored as base64-encoded, encrypted and gzipped Protobuf data.',
    2     => { Name => 'MeteringFrameCount',        Format => 'unsigned' },
    3     => { Name => 'OriginalPayloadFrameCount', Format => 'unsigned' },

);

%Image::ExifTool::Google::HDRPMakerNote = (
    GROUPS       => { 0 => 'MakerNotes', 2 => 'Image' },
    TAG_PREFIX   => '',
    PROCESS_PROC => \&ProcessHDRP,
    VARS         => { LONG_TAGS => 1 },
    NOTES        => q{
        Google text-based HDRP maker note tags.  Stored as base64-encoded,
        encrypted and gzipped text.
    },
    'InitParams'              => { Name => 'InitParamsText',      Binary => 1 },
    'Logging metadata'        => { Name => 'LoggingMetadataText', Binary => 1 },
    'Merged image'            => { Name => 'MergedImage',         Binary => 1 },
    'Finished image'          => { Name => 'FinishedImage',       Binary => 1 },
    'Payload frame'           => { Name => 'PayloadFrame',        Binary => 1 },
    'Payload metadata'        => { Name => 'PayloadMetadataText', Binary => 1 },
    'ShotLogData'             => { Name => 'ShotLogDataText',     Binary => 1 },
    'ShotParams'              => { Name => 'ShotParamsText',      Binary => 1 },
    'StaticMetadata'          => { Name => 'StaticMetadataText',  Binary => 1 },
    'Summary'                 => { Name => 'SummaryText',         Binary => 1 },
    'Time log'                => { Name => 'TimeLogText',         Binary => 1 },
    'Unused logging metadata' =>
      { Name => 'UnusedLoggingMetadata', Binary => 1 },
    'Rectiface'     => { Name => 'RectifaceText',    Binary => 1 },
    'GoudaRequest'  => { Name => 'GoudaRequestText', Binary => 1 },
    ProcessingNotes => {},
);

%Image::ExifTool::Google::PortraitReq = (
    GROUPS       => { 0 => 'MakerNotes', 2 => 'Image' },
    TAG_PREFIX   => '',
    PROCESS_PROC => \&ProcessHDRP,
    NOTES        => q{
        Google text-based PortraitRequest information.  Stored as base64-encoded,
        encrypted and gzipped text.
    },
);

sub ProcessHDRPMakerNote($$) {
    my ( $et, $dataPt ) = @_;
    my ( $tag, $dat, $pos );
    my $tagTbl = GetTagTable('Image::ExifTool::Google::HDRPMakerNote');
    for ( ; ; ) {
        my ( $end, $last );
        if ( $$dataPt =~ /^ ?([A-Z].*)$/mg ) {
            $end = pos($$dataPt) - length($1);
        }
        else {
            $end  = length($$dataPt);
            $last = 1;
        }
        if ($tag) {
            my $len = $end - ( $pos + 1 );
            last if $len <= 0;
            $et->HandleTag(
                $tagTbl, $tag,
                substr( $$dataPt, $pos + 1, $len ),
                MakeTagInfo => 1
            );
        }
        last if $last;
        $tag = $1;
        unless ( $tag =~ /:/ or $tag =~ /^\w+$/ ) {
            $et->HandleTag( $tagTbl, 'ProcessingNotes', $tag );
            undef $tag;
            next;
        }
        $pos = pos $$dataPt;
        if ( $tag =~ s/( \(base64\))?: ?(.*)// and $2 ) {
            my $dat = $2;
            $dat = Image::ExifTool::XMP::DecodeBase64($dat) if $1;
            $et->HandleTag( $tagTbl, $tag, $dat, MakeTagInfo => 1 );
            undef $tag;
        }
    }
}

sub ProcessHDRP($$$) {
    my ( $et, $dirInfo, $tagTbl ) = @_;
    my $dataPt  = $$dirInfo{DataPt};
    my $tagInfo = $$dirInfo{TagInfo};
    my $tagName = $tagInfo ? $$tagInfo{Name} : '';
    my $verbose = $et->Options('Verbose');
    my $fast    = $et->Options('FastScan') || 0;
    my ( $ver, $valPt );

    return undef if $fast > 1;

    if ( $$dirInfo{DirStart} ) {
        my $dat = substr( $$dataPt, $$dirInfo{DirStart}, $$dirInfo{DirLen} );
        $dataPt = \$dat;
    }
    if ( $$dataPt =~ /^HDRP[\x02\x03]/ ) {
        $valPt = $dataPt;
    }
    else {
        $et->VerboseDir( $tagName, undef, length($$dataPt) );
        $et->VerboseDump($dataPt) if $verbose > 2;
        $valPt = Image::ExifTool::XMP::DecodeBase64($$dataPt);
        if ( $verbose > 2 ) {
            $et->VerboseDir( "Base64-decoded $tagName", undef,
                length($$valPt) );
            $et->VerboseDump($valPt);
        }
    }
    if ( $$valPt =~ s/^HDRP([\x02\x03])// ) {
        $ver = ord($1);
    }
    else {
        $et->Warn('Unrecognized HDRP format');
        return undef;
    }
    my $pad = ( 8 - ( length($$valPt) % 8 ) ) & 0x07;
    $$valPt .= "\0" x $pad if $pad;
    my @words = unpack( 'V*', $$valPt );
    my ( $hi, $lo ) = ( 0x2515606b, 0x4a7791cd );
    my $i = 0;
    while ( $i < @words ) {
        $lo ^= $lo >> 12 | ( $hi & 0xfff ) << 20;
        $hi ^= $hi >> 12;
        $hi ^= ( $hi & 0x7f ) << 25 | $lo >> 7;
        $lo ^= ( $lo & 0x7f ) << 25;
        $lo ^= $lo >> 27 | ( $hi & 0x7ffffff ) << 5;
        $hi ^= $hi >> 27;
        my @a = unpack( 'n*', pack( 'N*', $hi, $lo ) );
        my @b = ( 0x2545, 0xf491, 0x4f6c, 0xdd1d );
        my @c = (0) x 7;
        my ( $j, $k );

        for ( $j = 0 ; $j < 4 ; ++$j ) {
            for ( $k = 0 ; $k < 4 ; ++$k ) {
                $c[ $j + $k ] += $a[$j] * $b[$k];
            }
        }
        for ( $j = 6 ; $j >= 3 ; --$j ) {
            while ( $c[$j] > 0xffffffff ) {
                ++$c[ $j - 2 ];
                $c[$j] -= 4294967296;
            }
            $c[ $j - 1 ] += $c[$j] >> 16;
            $c[$j] &= 0xffff;
        }
        $hi = ( $c[3] << 16 ) + $c[4];
        $lo = ( $c[5] << 16 ) + $c[6];
        $words[ $i++ ] ^= $lo;
        $words[ $i++ ] ^= $hi;
    }
    my $result;
    my $val = pack( 'V*', @words );
    $val = substr( $val, 0, -$pad ) if $pad;
    if ( $verbose > 2 ) {
        $et->VerboseDir( "Decrypted $tagName", undef, length($val) );
        $et->VerboseDump( \$val );
    }
    if ( eval { require IO::Uncompress::Gunzip } ) {
        my $buff;
        if ( IO::Uncompress::Gunzip::gunzip( \$val, \$buff ) ) {
            if ( $verbose > 2 ) {
                $et->VerboseDir( "Gunzipped $tagName", undef, length($buff) );
                $et->VerboseDump( \$buff );
            }
            if ( $ver == 3 or ( $tagInfo and $$tagInfo{IsProtobuf} ) ) {
                my %dirInfo = (
                    DataPt  => \$buff,
                    DirName => $tagName,
                );
                require Image::ExifTool::Protobuf;
                Image::ExifTool::Protobuf::ProcessProtobuf( $et, \%dirInfo,
                    $tagTbl );
            }
            else {
                ProcessHDRPMakerNote( $et, \$buff );
            }
            $result = \$buff;
        }
        else {
            $et->Warn(
                "Error inflating stream: $IO::Uncompress::Gunzip::GunzipError");
        }
    }
    else {
        $et->Warn('Install IO::Uncompress::Gunzip to decode HDRP makernote');
    }
    return $result;
}

1;

__END__

