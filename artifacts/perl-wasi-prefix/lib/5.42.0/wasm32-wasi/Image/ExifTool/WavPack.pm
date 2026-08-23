
package Image::ExifTool::WavPack;

use strict;
use vars            qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::RIFF;
use Image::ExifTool::APE;

$VERSION = '1.00';

%Image::ExifTool::WavPack::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS       => { 0 => 'File', 1 => 'File', 2 => 'Audio' },
    FORMAT       => 'int32u',
    NOTES        => q{
        Tags extracted from the header of WavPack (WV and WVP) audio files.  These
        files may also contain RIFF, ID3 and/or APE metadata which is also extracted
        by ExifTool.  See L<https://www.wavpack.com/WavPack5FileFormat.pdf> for the
        WavPack specification.
    },
    6.1 => {
        Name      => 'BytesPerSample',
        Mask      => 0x03,
        ValueConv => '$val + 1',
    },
    6.2 => {
        Name      => 'AudioType',
        Mask      => 0x04,
        PrintConv => { 0 => 'Stereo', 1 => 'Mono' },
    },
    6.3 => {
        Name      => 'Compression',
        Mask      => 0x08,
        PrintConv => { 0 => 'Lossless', 1 => 'Hybrid' },
    },
    6.4 => {
        Name      => 'DataFormat',
        Mask      => 0x80,
        PrintConv => { 0 => 'Integer', 1 => 'Floating Point' },
    },
    6.5 => {
        Name      => 'SampleRate',
        Mask      => 0x07800000,
        Priority  => 0,
        PrintConv => {
            0  => 6000,
            1  => 8000,
            2  => 9600,
            3  => 11025,
            4  => 12000,
            5  => 16000,
            6  => 22050,
            7  => 24000,
            8  => 32000,
            9  => 44100,
            10 => 48000,
            11 => 64000,
            12 => 88200,
            13 => 96000,
            14 => 192000,
            15 => 'Custom',
        },
    },
);

sub ProcessWV($$) {
    my ( $et, $dirInfo ) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    return 0 unless $raf->Read( $buff, 32 ) == 32;
    return 0 unless $buff =~ /^wvpk.{4}[\x02\x10]\x04/s;
    $et->SetFileType();
    my %dirInfo = (
        DataPt   => \$buff,
        DirStart => 0,
        DirLen   => length($buff),
    );
    $et->ProcessBinaryData( \%dirInfo,
        GetTagTable('Image::ExifTool::WavPack::Main') );
    $raf->Seek( 0, 0 );
    push @{ $$et{PATH} }, 'RIFF';
    Image::ExifTool::RIFF::ProcessRIFF( $et, $dirInfo );
    $$et{PATH}[-1] = 'APE';
    Image::ExifTool::APE::ProcessAPE( $et, $dirInfo );
    pop @{ $$et{PATH} };
    return 1;
}

1;

__END__

