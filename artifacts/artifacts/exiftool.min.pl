#!/usr/bin/env perl
use strict;
use warnings;
require 5.004;

my $version = '13.59';

$^W = 1;

my $exePath;

BEGIN {
    $exePath = @ARGV && lc( $ARGV[0] ) eq '-xpath' && shift() ? $^X : $0;
    my $exeDir = ( $exePath =~ /(.*)[\\\/]/ ) ? $1       : '.';
    my $incDir = ( $0       =~ /(.*)[\\\/]/ ) ? "$1/lib" : './lib';
    if ( -l $0 ) {
        my $lnk = eval { readlink $0 };
        if ( defined $lnk ) {
            my $lnkDir = ( $lnk =~ /(.*)[\\\/]/ ) ? $1 : '.';
            $exeDir = ( ( $lnk =~ m(^/) ) ? '' : $exeDir . '/' ) . $lnkDir;
            $incDir = "$exeDir/lib";
        }
    }
    $Image::ExifTool::exeDir = $exeDir;

    unshift @INC, $incDir;
    while ( @ARGV and lc( $ARGV[0] ) eq '-config' ) {
        shift;
        push @Image::ExifTool::configFiles, shift;
    }
}
use Image::ExifTool qw{:Public};

sub SigInt();
sub SigCont();
sub Cleanup();
sub GetImageInfo($$);
sub SetImageInfo($$$);
sub DoHardLink($$$$$);
sub CleanXML($);
sub EncodeXML($);
sub FormatXML($$$);
sub EscapeJSON($;$);
sub FormatJSON($$$;$);
sub PrintCSV(;$);
sub AddGroups($$$$);
sub ConvertBinary($);
sub IsEqual($$;$);
sub Printable($);
sub LengthUTF8($);
sub Infile($;$);
sub AddSetTagsFile($;$);
sub Warning($$);
sub DoSetFromFile($$$);
sub CleanFilename($);
sub HasWildcards($);
sub SetWindowTitle($);
sub ProcessFiles($;$);
sub ScanDir($$;$);
sub FindFileWindows($$);
sub FileNotFound($);
sub PreserveTime();
sub AbsPath($);
sub MyConvertFileName($$);
sub SuggestedExtension($$$);
sub LoadPrintFormat($;$);
sub FilenameSPrintf($;$@);
sub NextUnusedFilename($;$);
sub CreateDirectory($);
sub OpenOutputFile($;@);
sub AcceptFile($);
sub SlurpFile($$);
sub FilterArgfileLine($);
sub ReadStayOpen($);
sub Progress($$);
sub PrintTagList($@);
sub PrintErrors($$$);
sub GetASCII($);

END {
    Cleanup();
}

my @commonArgs;
my @condition;
my @csvExclude;
my @csvFiles;
my @csvTags;
my @delFiles;
my @dynamicFiles;
my ( @echo3, @echo4 );
my @efile;
my @exclude;
my @files;
my @moreArgs;
my @newValues;
my @requestTags;
my @srcFmt;
my @tags;
my %altFile;
my %appended;
my %countLink;
my %created;
my %csvTags;
my %database;
my %filterExt;
my %ignore;
my %outComma;
my %outTrailer;
my %preserveTime;
my %printFmt;
my %seqFileDir;
my %setTags;
my %setTagsList;
my %usedFileName;
my %utf8FileName;
my %warnedOnce;
my %wext;
my %wroteHEAD;
my $allGroup;
my $altEnc;
my $argFormat;
my $binaryOutput;
my $binaryStdout;
my $binSep;
my $binTerm;
my $comma;
my $count;
my $countBad;
my $countBadCr;
my $countBadWr;
my $countCopyWr;
my $countDir;
my $countFailed;
my $countGoodCr;
my $countGoodWr;
my $countNewDir;
my $countSameWr;
my $critical;
my $csv;
my $csvDelim;
my $dbAdd;
my $dbSaveCount;
my $deleteOrig;
my $diff;
my $disableOutput;
my $doSetFileName;
my $doUnzip;
my ( $end, $endDir, %endDir );
my $escapeC;
my $escapeHTML;
my $evalWarning;
my $executeID;
my $failCondition;
my $fastCondition;
my $fileHeader;
my $fileTrailer;
my $filtered;
my $filterFlag;
my $fixLen;
my $forcePrint;
my $geoOnly;
my $helped;
my $html;
my $ignoreHidden;
my $interrupted;
my $isBinary;
my $isWriting;
my $joinLists;
my $json;
my $langOpt;
my $listDir;
my $listItem;
my $listSep;
my $mt;
my $multiFile;
my $noBinary;
my $outFormat;
my $outOpt;
my $overwriteOrig;
my $pause;
my $plot;
my $preserveTime;
my $progress;
my $progressCount;
my $progressIncr;
my $progressMax;
my $progressNext;
my $progStr;
my $purge;
my $quiet;
my $rafStdin;
my $recurse;
my $rtnVal;
my $rtnValPrev;
my $saveCount;
my $scanWritable;
my $sectHeader;
my $sectTrailer;
my $seqFileDir;
my $seqFileNum;
my $setCharset;
my $showGroup;
my $showTagID;
my $stayOpenBuff = '';
my $stayOpenFile;
my $structOpt;
my $tabFormat;
my $tagOut;
my $textOut;
my $textOut2;
my $textOverwrite;
my $tmpFile;
my $tmpText;
my $validFile;
my $verbose;
my $vout;
my $windowTitle;
my $xml;

my $stayOpen = 0;

my $rtnValApp = 0;
my $curTitle  = '';

my $isCRLF = { MSWin32 => 1, os2 => 1, dos => 1 }->{$^O};

my %jsonChar =
  ( '"' => '"', '\\' => '\\', "\t" => 't', "\n" => 'n', "\r" => 'r' );

my %escC   = ( "\n" => '\n', "\r" => '\r', "\t" => '\t', '\\' => '\\\\' );
my %unescC = (
    a    => "\a",
    b    => "\b",
    f    => "\f",
    n    => "\n",
    r    => "\r",
    t    => "\t",
    0    => "\0",
    '\\' => '\\'
);

my %optArgs = (
    '-tagsfromfile'    => 1,
    '-addtagsfromfile' => 1,
    '-alltagsfromfile' => 1,
    '-@'               => 1,
    '-api'             => 1,
    '-c'               => 1,
    '-coordformat'     => 1,
    '-charset'         => 0,
    '-config'          => 1,
    '-csvdelim'        => 1,
    '-d'               => 1,
    '-dateformat'      => 1,
    '-D'               => 0,
    '-diff'            => 1,
    '-echo'            => 1,
    '-echo#'           => 1,
    '-efile'           => 1,
    '-efile#'          => 1,
    '-efile!'          => 1,
    '-efile#!'         => 1,
    '-ext'             => 1,
    '--ext'            => 1,
    '-ext+'            => 1,
    '--ext+'           => 1,
    '-extension'       => 1,
    '--extension'      => 1,
    '-extension+'      => 1,
    '--extension+'     => 1,
    '-fileorder'       => 1,
    '-fileorder#'      => 1,
    '-file#'           => 1,
    '-geotag'          => 1,
    '-globaltimeshift' => 1,
    '-i'               => 1,
    '-ignore'          => 1,
    '-if'              => 1,
    '-if#'             => 1,
    '-lang'            => 0,
    '-listitem'        => 1,
    '-o'               => 1,
    '-out'             => 1,
    '-p'               => 1,
    '-printformat'     => 1,
    '-p-'              => 1,
    '-printformat-'    => 1,
    '-P'               => 0,
    '-password'        => 1,
    '-require'         => 1,
    '-sep'             => 1,
    '-separator'       => 1,
    '-srcfile'         => 1,
    '-stay_open'       => 1,
    '-use'             => 1,
    '-userparam'       => 1,
    '-w'               => 1,
    '-w!'              => 1,
    '-w+'              => 1,
    '-w+!'             => 1,
    '-w!+'             => 1,
    '-textout'         => 1,
    '-textout!'        => 1,
    '-textout+'        => 1,
    '-textout+!'       => 1,
    '-textout!+'       => 1,
    '-tagout'          => 1,
    '-tagout!'         => 1,
    '-tagout+'         => 1,
    '-tagout+!'        => 1,
    '-tagout!+'        => 1,
    '-wext'            => 1,
    '-wm'              => 1,
    '-writemode'       => 1,
    '-x'               => 1,
    '-exclude'         => 1,
    '-X'               => 0,
);

my @recommends = qw(
  Archive::Zip
  Compress::Zlib
  Digest::MD5
  Digest::SHA
  IO::Compress::Bzip2
  POSIX::strptime
  Time::Local
  Unicode::LineBreak
  File::StatX
  Compress::Raw::Lzma
  IO::Compress::RawDeflate
  IO::Uncompress::RawInflate
  IO::Compress::Brotli
  IO::Uncompress::Brotli
  Win32::API
  Win32::FindFile
  Win32API::File
);
my %altRecommends = ( 'POSIX::strptime' => 'Time::Piece', );

my %unescapeChar = ( 't' => "\t", 'n' => "\n", 'r' => "\r" );

sub Image::ExifTool::EndDir() { return $endDir = 1 }
sub Image::ExifTool::End()    { return $end    = 1 }

sub Exit {
    if ($pause) {
        if ( eval { require Term::ReadKey } ) {
            print STDERR "-- press any key --";
            Term::ReadKey::ReadMode('cbreak');
            Term::ReadKey::ReadKey(0);
            Term::ReadKey::ReadMode(0);
            print STDERR "\b \b" x 20;
        }
        else {
            print STDERR "-- press RETURN --\n";
            <STDIN>;
        }
    }
    exit shift;
}

sub Warn {
    if ( $quiet < 2 or $_[0] =~ /^Error/ ) {
        my $oldWarn = $SIG{'__WARN__'};
        delete $SIG{'__WARN__'};
        warn(@_);
        $SIG{'__WARN__'} = $oldWarn if defined $oldWarn;
    }
}
sub Error { Warn @_; $rtnVal = 1; }

sub WarnOnce($) {
    Warn(@_) and $warnedOnce{ $_[0] } = 1 unless $warnedOnce{ $_[0] };
}

sub SigInt() {
    $critical and $interrupted = 1, return;
    Cleanup();
    exit 1;
}
sub SigCont() { }

sub Cleanup() {
    $mt->Unlink($tmpFile) if defined $tmpFile;
    $mt->Unlink($tmpText) if defined $tmpText;
    undef $tmpFile;
    undef $tmpText;
    PreserveTime() if %preserveTime;
    SetWindowTitle('');
}

if ( grep /^-common_args$/i, @ARGV ) {
    my ( @newArgs, $common, $end );
    foreach (@ARGV) {
        if ( /^-common_args$/i and not $end ) {
            $common = 1;
        }
        elsif ($common) {
            push @commonArgs, $_;
        }
        else {
            $end = 1 if $_ eq '--';
            push @newArgs, $_;
        }
    }
    @ARGV = @newArgs if $common;
}

Command: for ( ; ; ) {

    if (@echo3) {
        my $str = join( "\n", @echo3 ) . "\n";
        $str =~ s/\$\{status\}/$rtnVal/ig;
        print STDOUT $str;
    }
    if (@echo4) {
        my $str = join( "\n", @echo4 ) . "\n";
        $str =~ s/\$\{status\}/$rtnVal/ig;
        print STDERR $str;
    }

    $rafStdin->Close() if $rafStdin;
    undef $rafStdin;

    $rtnValPrev = $rtnVal;
    $rtnValApp  = $rtnVal if $rtnVal;

    last unless @ARGV or not defined $rtnVal or $stayOpen >= 2 or @commonArgs;

    if ($binaryStdout) {
        binmode( STDOUT, ':crlf' ) if $] >= 5.006 and $isCRLF;
        $binaryStdout = 0;
    }

    if ( $stayOpen >= 2 ) {
        if ( $quiet and not defined $executeID ) {
            eval { require IO::Handle } and STDERR->flush(), STDOUT->flush();
        }
        else {
            eval { require IO::Handle } and STDERR->flush();
            my $id   = defined $executeID ? $executeID : '';
            my $save = $|;
            $| = 1;
            print "{ready$id}\n";
            $| = $save;
        }
    }

    undef @condition;
    undef @csvExclude;
    undef @csvFiles;
    undef @csvTags;
    undef @delFiles;
    undef @dynamicFiles;
    undef @echo3;
    undef @echo4;
    undef @efile;
    undef @exclude;
    undef @files;
    undef @newValues;
    undef @requestTags;
    undef @srcFmt;
    undef @tags;
    undef %altFile;
    undef %appended;
    undef %countLink;
    undef %created;
    undef %csvTags;
    undef %database;
    undef %endDir;
    undef %filterExt;
    undef %ignore;
    undef %outComma;
    undef %outTrailer;
    undef %preserveTime;
    undef %printFmt;
    undef %seqFileDir;
    undef %setTags;
    undef %setTagsList;
    undef %usedFileName;
    undef %utf8FileName;
    undef %warnedOnce;
    undef %wext;
    undef %wroteHEAD;
    undef $allGroup;
    undef $altEnc;
    undef $argFormat;
    undef $binaryOutput;
    undef $binSep;
    undef $binTerm;
    undef $comma;
    undef $csv;
    undef $dbAdd;
    undef $deleteOrig;
    undef $diff;
    undef $disableOutput;
    undef $doSetFileName;
    undef $doUnzip;
    undef $end;
    undef $endDir;
    undef $escapeC;
    undef $escapeHTML;
    undef $evalWarning;
    undef $executeID;
    undef $failCondition;
    undef $fastCondition;
    undef $fileHeader;
    undef $filtered;
    undef $fixLen;
    undef $forcePrint;
    undef $geoOnly;
    undef $ignoreHidden;
    undef $isBinary;
    undef $joinLists;
    undef $langOpt;
    undef $listDir;
    undef $listItem;
    undef $multiFile;
    undef $noBinary;
    undef $outOpt;
    undef $plot;
    undef $preserveTime;
    undef $progress;
    undef $progressCount;
    undef $progressIncr;
    undef $progressMax;
    undef $progressNext;
    undef $purge;
    undef $rafStdin;
    undef $recurse;
    undef $scanWritable;
    undef $sectHeader;
    undef $setCharset;
    undef $showGroup;
    undef $showTagID;
    undef $structOpt;
    undef $tagOut;
    undef $textOut;
    undef $textOut2;
    undef $textOverwrite;
    undef $tmpFile;
    undef $tmpText;
    undef $validFile;
    undef $verbose;
    undef $windowTitle;

    $count         = 0;
    $countBad      = 0;
    $countBadCr    = 0;
    $countBadWr    = 0;
    $countCopyWr   = 0;
    $countDir      = 0;
    $countFailed   = 0;
    $countGoodCr   = 0;
    $countGoodWr   = 0;
    $countNewDir   = 0;
    $countSameWr   = 0;
    $csvDelim      = ',';
    $dbSaveCount   = 0;
    $fileTrailer   = '';
    $filterFlag    = 0;
    $html          = 0;
    $isWriting     = 0;
    $json          = 0;
    $listSep       = ', ';
    $outFormat     = 0;
    $overwriteOrig = 0;
    $progStr       = '';
    $quiet         = 0;
    $rtnVal        = 0;
    $saveCount     = 0;
    $sectTrailer   = '';
    $seqFileDir    = 0;
    $seqFileNum    = 0;
    $tabFormat     = 0;
    $vout          = \*STDOUT;
    $xml           = 0;

    my @fileOrder;
    my $fileOrderFast;
    my $addGeotime;
    my $doGlob;
    my $endOfOpts;
    my $escapeXML;
    my $setTagsFile;
    my $sortOpt;
    my $srcStdin;
    my $tagsFrom = '';
    my $useMWG;

    my ( $argsLeft, @nextPass, $badCmd );
    my $pass = 0;

    if ( $^O eq 'MSWin32' and eval { require File::Glob } ) {
        import File::Glob qw(:globally :nocase);
        $doGlob = 1;
    }

    $mt = Image::ExifTool->new;

    $mt->Options( Duplicates => 0 )
      unless %Image::ExifTool::UserDefined::Options
      and defined $Image::ExifTool::UserDefined::Options{Duplicates};

    $joinLists = 1 if defined $mt->Options('List') and not $mt->Options('List');

    if ( not $preserveTime and $^O eq 'MSWin32' ) {
        $preserveTime = 2
          if eval { require Win32::API } and eval { require Win32API::File };
    }

    if (@Image::ExifTool::UserDefined::Arguments) {
        unshift @ARGV, @Image::ExifTool::UserDefined::Arguments;
    }

    if ( $version ne $Image::ExifTool::VERSION ) {
        Warn
"Application version $version does not match Image::ExifTool library version $Image::ExifTool::VERSION\n";
    }

    for ( ; ; ) {

        if (
            not @ARGV
            or ( $ARGV[0] =~ /^(-|\xe2\x88\x92)execute(\d+)?$/i
                and not $endOfOpts )
          )
        {
            if (@ARGV) {
                $executeID = $2;
                $helped    = 1;
                $badCmd and shift, $rtnVal = 1, next Command;
            }
            elsif ( $stayOpen >= 2 ) {
                ReadStayOpen( \@ARGV );
                next;
            }
            elsif ($badCmd) {
                undef @commonArgs;
                $rtnVal = 1;
                next Command;
            }
            if ( $pass == 0 ) {
                if ( @commonArgs and not defined $argsLeft ) {
                    $argsLeft = scalar(@ARGV) + scalar(@moreArgs);
                    unshift @ARGV, @commonArgs;
                    undef @commonArgs unless $argsLeft;
                    next;
                }
                if ( defined $argsLeft
                    and $argsLeft < scalar(@ARGV) + scalar(@moreArgs) )
                {
                    Warn
"Ignoring -common_args from $ARGV[0] onwards to avoid infinite recursion\n";
                    while ( $argsLeft < scalar(@ARGV) + scalar(@moreArgs) ) {
                        @ARGV and shift(@ARGV), next;
                        shift @moreArgs;
                    }
                }
                $useMWG = 1
                  if not $useMWG
                  and grep /^([--_0-9A-Z]+:)*1?mwg:/i, @tags, @requestTags;
                if ($useMWG) {
                    require Image::ExifTool::MWG;
                    Image::ExifTool::MWG::Load();
                }
                if ( defined $forcePrint ) {
                    unless ( defined $mt->Options('MissingTagValue') ) {
                        $mt->Options( MissingTagValue => '-' );
                    }
                    $forcePrint = $mt->Options('MissingTagValue');
                }
            }
            if (@nextPass) {
                unshift @ARGV, @nextPass;
                undef @nextPass;
                undef $endOfOpts;
                ++$pass;
                next;
            }
            @ARGV and shift;
            last;
        }
        $_ = shift;
        next if $badCmd;

        if ( not $endOfOpts and s/^(-|\xe2\x88\x92)// ) {
            s/^\xe2\x88\x92/-/;
            if ( $_ eq '-' ) {
                $pass or push @nextPass, '--';
                $endOfOpts = 1;
                next;
            }
            my $a = lc $_;
            if (/^list([wfrdx]|wf|g(\d*)|geo)?$/i) {
                $pass or push @nextPass, "-$_";
                my $type = lc( $1 || '' );
                if ( not $type or $type eq 'w' or $type eq 'x' ) {
                    my $group;
                    if (    $ARGV[0]
                        and $ARGV[0] =~ /^(-|\xe2\x88\x92)(.+):(all|\*)$/i )
                    {
                        if ( $pass == 0 ) {
                            $useMWG = 1 if lc($2) eq 'mwg';
                            push @nextPass, shift;
                            next;
                        }
                        $group = $2;
                        shift;
                        $group =~ /IFD/i
                          and Warn("Can't list tags for specific IFD\n"),
                          $helped = 1, next;
                        $group =~ /^(all|\*)$/ and undef $group;
                    }
                    else {
                        $pass or next;
                    }
                    $helped = 1;
                    if ( $type eq 'x' ) {
                        require Image::ExifTool::TagInfoXML;
                        my %opts;
                        $opts{Flags}  = 1 if defined $forcePrint;
                        $opts{NoDesc} = 1 if $outFormat > 0;
                        $opts{Lang}   = $langOpt;
                        Image::ExifTool::TagInfoXML::Write( undef, $group,
                            %opts );
                        next;
                    }
                    my $wr  = ( $type eq 'w' );
                    my $msg = ( $wr ? 'Writable' : 'Available' )
                      . ( $group ? " $group" : '' ) . ' tags';
                    PrintTagList( $msg,
                        $wr ? GetWritableTags($group) : GetAllTags($group) );
                    next if $group or $wr;
                    my @tagList = GetShortcuts();
                    PrintTagList( 'Command-line shortcuts', @tagList )
                      if @tagList;
                    next;
                }
                $pass or next;
                $helped = 1;
                if ( $type eq 'wf' ) {
                    my @wf;
                    CanWrite($_) and push @wf, $_ foreach GetFileType();
                    PrintTagList( 'Writable file extensions', @wf );
                }
                elsif ( $type eq 'f' ) {
                    PrintTagList( 'Supported file extensions', GetFileType() );
                }
                elsif ( $type eq 'r' ) {
                    PrintTagList(
                        'Recognized file extensions',
                        GetFileType( undef, 0 )
                    );
                }
                elsif ( $type eq 'd' ) {
                    PrintTagList( 'Deletable groups', GetDeleteGroups() );
                }
                elsif ( $type eq 'geo' ) {
                    require Image::ExifTool::Geolocation;
                    my ( $i, $entry );
                    print "Geolocation database:\n" unless $quiet;
                    my $isAlt =
                      $mt->Options('GeolocAltNames') ? ',AltNames' : '';
                    $isAlt = ''
                      if $isAlt
                      and not Image::ExifTool::Geolocation::ReadAltNames();
                    print
"City,Region,Subregion,CountryCode,Country,TimeZone,FeatureCode,Population,Latitude,Longitude$isAlt\n";
                    Image::ExifTool::Geolocation::SortDatabase('City')
                      if $sortOpt;
                    my $minPop  = $mt->Options('GeolocMinPop');
                    my $feature = $mt->Options('GeolocFeature') || '';
                    my $neg     = $feature =~ s/^-//;
                    my %fcodes  = map { lc($_) => 1 } split /\s*,\s*/, $feature;
                    my @isUTF8  = ( 0, 1, 2, 4 );
                    push @isUTF8, 10 if $isAlt;

                    for ( $i = 0 ; ; ++$i ) {
                        my @entry =
                          Image::ExifTool::Geolocation::GetEntry( $i, $langOpt,
                            1 )
                          or last;
                        $#entry = 9;
                        next if $minPop and $entry[7] < $minPop;
                        next
                          if %fcodes
                          and $neg
                          ? $fcodes{ lc $entry[6] }
                          : not $fcodes{ lc $entry[6] };
                        push @entry,
                          Image::ExifTool::Geolocation::GetAltNames( $i, 1 )
                          if $isAlt;
                        $_ = defined $_ ? $mt->Decode( $_, 'UTF8' ) : ''
                          foreach @entry[@isUTF8];
                        pop @entry if $isAlt and not $entry[10];
                        print join( ',', @entry ), "\n";
                    }
                }
                else {

                    my $family = $2 || 0;
                    PrintTagList(
                        "Groups in family $family",
                        $mt->GetAllGroups($family)
                    );
                }
                next;
            }
            if ( $a eq 'ver' ) {
                $pass or push( @nextPass, '-ver' ), next;
                my $libVer = $Image::ExifTool::VERSION;
                my $str =
                  $libVer eq $version
                  ? ''
                  : " [Warning: Library version is $libVer]";
                if ($verbose) {
                    print
"ExifTool version $version$str$Image::ExifTool::RELEASE\n";
                    printf "Perl version %s%s\n", $],
                      ( defined ${^UNICODE} ? " (-C${^UNICODE})" : '' );
                    print "Platform: $^O\n";
                    if ( $verbose > 8 ) {
                        print "Current Dir: " . Cwd::getcwd() . "\n"
                          if ( eval { require Cwd } );
                        print "Script Name: $0\n";
                        print "Exe Name:    $^X\n";
                        print "Exe Dir:     $Image::ExifTool::exeDir\n";
                        print "Exe Path:    $exePath\n";
                    }
                    print "Optional libraries:\n";
                    foreach (@recommends) {
                        next if /^Win32/ and $^O ne 'MSWin32';
                        next if /StatX/  and $^O ne 'linux';
                        my $ver = eval "require $_ and \$${_}::VERSION";
                        my $alt = $altRecommends{$_};
                        $ver = eval "require $alt and \$${alt}::VERSION"
                          and $_ = $alt
                          if not $ver and $alt;
                        printf "  %-28s %s\n", $_, $ver || '(not installed)';
                    }
                    if ( $verbose > 1 ) {
                        print "Include directories:\n";
                        ref $_ or print "  $_\n" foreach @INC;
                    }
                }
                else {
                    print "$version$str$Image::ExifTool::RELEASE\n";
                }
                $helped = 1;
                next;
            }
            if (/^(all|add)?tagsfromfile(=.*)?$/i) {
                $setTagsFile = $2 ? substr( $2, 1 ) : ( @ARGV ? shift : '' );
                if ( $setTagsFile eq '' ) {
                    Error("File must be specified for -tagsFromFile option\n");
                    $badCmd = 1;
                    next;
                }
                AddSetTagsFile( $setTagsFile,
                    { Replace => ( $1 and lc($1) eq 'add' ) ? 0 : 1 } );
                $tagsFrom = 'File';
                next;
            }
            if ( $a eq '@' ) {
                my $argFile = shift
                  or Error("Expecting filename for -\@ option\n"), $badCmd = 1,
                  next;
                if ( $stayOpen == 1 ) {
                    @moreArgs = @ARGV;
                    undef @ARGV;
                }
                elsif ( $stayOpen == 3 ) {
                    if (    $stayOpenFile
                        and $stayOpenFile ne '-'
                        and $argFile eq $stayOpenFile )
                    {
                        $stayOpen = 2;
                        Warn
"Ignoring request to switch to the same -stay_open ARGFILE ($argFile)\n";
                        next;
                    }
                    close STAYOPEN;
                    $stayOpen = 1;
                }
                my $fp = ( $stayOpen == 1 ? \*STAYOPEN : \*ARGFILE );
                unless ( $mt->Open( $fp, $argFile ) ) {
                    unless ($argFile !~ /^\//
                        and
                        $mt->Open( $fp, "$Image::ExifTool::exeDir/$argFile" ) )
                    {
                        Error "Error opening arg file $argFile\n";
                        $badCmd = 1;
                        next;
                    }
                }
                if ( $stayOpen == 1 ) {
                    $stayOpenFile = $argFile;
                    $stayOpenBuff = '';
                    $stayOpen     = 2;
                    $helped       = 1;
                    ReadStayOpen( \@ARGV );
                    next;
                }
                my ( @newArgs, $didBOM );
                foreach (<ARGFILE>) {
                    unless ($didBOM) {
                        s/^\xef\xbb\xbf//;
                        $didBOM = 1;
                    }
                    $_ = FilterArgfileLine($_);
                    push @newArgs, $_ if defined $_;
                }
                close ARGFILE;
                unshift @ARGV, @newArgs;
                next;
            }
            /^(-?)(a|duplicates)$/i
              and $mt->Options( Duplicates => ( $1 ? 0 : 1 ) ), next;
            if ( $a eq 'api' ) {
                my $opt = shift;
                if ( defined $opt and length $opt ) {
                    my $val = ( $opt =~ s/=(.*)//s ) ? $1 : 1;
                    $val = undef unless $opt =~ s/\^$// or length $val;
                    $mt->Options( $opt => $val );
                }
                else {
                    unless ($pass) {
                        push @nextPass, '-api';
                        push @nextPass, $opt if defined $opt;
                        next;
                    }
                    print "Available API Options:\n";
                    my $availableOptions = Image::ExifTool::AvailableOptions();
                    $$_[3]
                      or printf( "  %-17s - %s\n", $$_[0], $$_[2] )
                      foreach @$availableOptions;
                    $helped = 1;
                }
                next;
            }
            /^arg(s|format)$/i and $argFormat = 1, next;
            if (/^(-?)b(inary)?$/i) {
                ( $binaryOutput, $noBinary ) = $1 ? ( undef, 1 ) : ( 1, undef );
                $mt->Options(
                    Binary    => $binaryOutput,
                    NoPDFList => $binaryOutput
                );
                next;
            }
            if (/^c(oordFormat)?$/i) {
                my $fmt = shift;
                $fmt
                  or Error("Expecting coordinate format for -c option\n"),
                  $badCmd = 1, next;
                $mt->Options( 'CoordFormat', $fmt );
                next;
            }
            if ( $a eq 'charset' ) {
                my $charset =
                  ( @ARGV and $ARGV[0] !~ /^(-|\xe2\x88\x92)/ ) ? shift : undef;
                if ( not $charset ) {
                    unless ($pass) {
                        push @nextPass, '-charset';
                        push @nextPass, $charset if defined $charset;
                        next;
                    }
                    my %charsets;
                    $charsets{$_} = 1
                      foreach values %Image::ExifTool::charsetName;
                    PrintTagList( 'Available character sets',
                        sort keys %charsets );
                    $helped = 1;
                }
                elsif ( $charset !~ s/^(\w+)=// or lc($1) eq 'exiftool' ) {
                    {
                        local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
                        undef $evalWarning;
                        $mt->Options( Charset => $charset );
                    }
                    if ($evalWarning) {
                        Warn $evalWarning;
                    }
                    else {
                        $setCharset = $mt->Options('Charset');
                    }
                }
                else {
                    my $type = {
                        id3       => 'ID3',
                        iptc      => 'IPTC',
                        exif      => 'EXIF',
                        filename  => 'FileName',
                        photoshop => 'Photoshop',
                        quicktime => 'QuickTime',
                        riff      => 'RIFF'
                    }->{ lc $1 };
                    $type
                      or Warn("Unknown type for -charset option: $1\n"), next;
                    $mt->Options( "Charset$type" => $charset );
                }
                next;
            }
            /^config$/i
              and Warn("Ignored -config option (not first on command line)\n"),
              shift, next;
            if (/^(csv|j(son)?)(\+?=.*)?$/i) {
                my $dbFile = $3;
                my $dbType = lc($1) eq 'csv' ? 'CSV' : 'JSON';
                unless ($dbFile) {
                    if ( $dbType eq 'CSV' ) {
                        $csv = $dbType;
                    }
                    else {
                        $json = 1;
                        $html = $xml = 0;
                        $mt->Options( Duplicates => 1 );
                        require Image::ExifTool::XMP;
                    }
                    next;
                }
                unless ($pass) {
                    @tags
                      and
                      Warn("Tag arguments should come after the -$1= option\n");
                    push @nextPass, "-$_";
                    push @newValues, { SaveCount => ++$saveCount };
                    $dbSaveCount = $saveCount;
                    $tagsFrom    = 'CSV';
                    next;
                }
                $dbFile =~ s/^(\+?=)//;
                $dbAdd = 2        if $1 eq '+=';
                $vout  = \*STDERR if $srcStdin;
                $verbose and print $vout "Reading $dbType file $dbFile\n";
                my $msg;
                if ( $mt->Open( \*CSVFILE, $dbFile ) ) {
                    binmode CSVFILE;
                    require Image::ExifTool::Import;
                    if ( $dbType eq 'CSV' ) {
                        $msg = Image::ExifTool::Import::ReadCSV( \*CSVFILE,
                            \%database, $forcePrint, $csvDelim );
                    }
                    else {
                        my $chset = $mt->Options('Charset');
                        $msg = Image::ExifTool::Import::ReadJSON( \*CSVFILE,
                            \%database, $forcePrint, $chset );
                    }
                    close(CSVFILE);
                }
                else {
                    $msg = "Error opening $dbType file '${dbFile}'";
                }
                $msg and Warn("$msg\n");
                $isWriting = 1;
                $csv       = $dbType;
                next;
            }
            if (/^csvdelim$/i) {
                $csvDelim = shift;
                defined $csvDelim
                  or Error("Expecting argument for -csvDelim option\n"),
                  $badCmd = 1, next;
                $csvDelim =~ /"/
                  and Error("CSV delimiter can not contain a double quote\n"),
                  $badCmd = 1, next;
                my %unescape =
                  ( 't' => "\t", 'n' => "\n", 'r' => "\r", '\\' => '\\' );
                $csvDelim =~ s/\\(.)/$unescape{$1}||"\\$1"/sge;
                $mt->Options( CSVDelim => $csvDelim );
                next;
            }
            if ( /^d$/ or $a eq 'dateformat' ) {
                my $fmt = shift;
                $fmt
                  or Error("Expecting date format for -d option\n"),
                  $badCmd = 1, next;
                $mt->Options( 'DateFormat', $fmt );
                next;
            }
            ( /^D$/ or $a eq 'decimal' ) and $showTagID = 'D', next;
            if (/^diff$/i) {
                $diff = shift;
                defined $diff
                  or Error("Expecting file name for -$_ option\n"), $badCmd = 1;
                CleanFilename($diff);
                next;
            }
            /^delete_original(!?)$/i and $deleteOrig = ( $1 ? 2 : 1 ), next;
            /^list_dir$/i and $listDir = 1, next;
            ( /^e$/ or $a eq '-composite' )
              and $mt->Options( Composite => 0 ), next;
            ( /^-e$/ or $a eq 'composite' )
              and $mt->Options( Composite => 1 ), next;
            ( /^E$/ or $a eq 'escapehtml' or $a eq 'eh' )
              and require Image::ExifTool::HTML
              and $escapeHTML = 1, next;
            ( $a eq 'ec' or $a eq 'escapec' )   and $escapeC   = 1, next;
            ( $a eq 'ex' or $a eq 'escapexml' ) and $escapeXML = 1, next;

            if (/^echo(\d)?$/i) {
                my $n   = $1 || 1;
                my $arg = shift;
                next unless defined $arg;
                $n > 4 and Warn("Invalid -echo number\n"), next;
                if ( $n > 2 ) {
                    $n == 3 ? push( @echo3, $arg ) : push( @echo4, $arg );
                }
                else {
                    print { $n == 2 ? \*STDERR : \*STDOUT } $arg, "\n";
                }
                $helped = 1;
                next;
            }
            if (/^(ee|extractembedded)(\d*)$/i) {
                $mt->Options( ExtractEmbedded => $2 || 1 );
                $mt->Options( Duplicates      => 1 );
                next;
            }
            if (/^efile(\d+)?(!)?$/i) {
                my $arg = shift;
                defined $arg
                  or Error("Expecting file name for -$_ option\n"),
                  $badCmd = 1, next;
                $efile[0] = $arg if not $1 or $1 & 0x01;
                $efile[1] = $arg if $1 and $1 & 0x02;
                $efile[2] = $arg if $1 and $1 & 0x04;
                $efile[3] = $arg if $1 and $1 & 0x08;
                $efile[4] = $arg if $1 and $1 & 0x016;
                unlink $arg if $2;
                next;
            }
            if (/^-?ext(ension)?(\+)?$/i) {
                my $ext = shift;
                defined $ext
                  or Error("Expecting extension for -ext option\n"),
                  $badCmd = 1, next;
                my $flag = /^-/ ? 0 : ( $2 ? 2 : 1 );
                $filterFlag |= ( 0x01 << $flag );
                $ext =~ s/^\.//;
                $filterExt{ uc($ext) } = $flag ? 1 : 0;
                next;
            }
            if ( /^f$/ or $a eq 'forceprint' ) {
                $forcePrint = 1;
                next;
            }
            if ( /^F([-+]?\d*)$/ or /^fixbase([-+]?\d*)$/i ) {
                $mt->Options( FixBase => $1 );
                next;
            }
            if (/^fast(\d*)$/i) {
                $mt->Options( FastScan => ( length $1 ? $1 : 1 ) );
                next;
            }
            if (/^(file\d+)$/i) {
                $altFile{ lc $1 } = shift
                  or Error("Expecting file name for -file option\n"),
                  $badCmd = 1, next;
                next;
            }
            if (/^fileorder(\d*)$/i) {
                push @fileOrder, shift if @ARGV;
                my $num = $1 || 0;
                $fileOrderFast = $num
                  if not defined $fileOrderFast or $fileOrderFast > $num;
                next;
            }
            $a eq 'globaltimeshift'
              and $mt->Options( GlobalTimeShift => shift ), next;
            if (/^(g)(roupHeadings|roupNames)?([\d:]*)$/i) {
                $showGroup = $3 || 0;
                $allGroup  = ( $2 ? lc($2) eq 'roupnames' : $1 eq 'G' );
                $mt->Options( SavePath   => 1 ) if $showGroup =~ /\b5\b/;
                $mt->Options( SaveFormat => 1 ) if $showGroup =~ /\b6\b/;
                next;
            }
            if ( $a eq 'geotag' ) {
                my $trkfile = shift;
                unless ($pass) {
                    push @nextPass, '-geotag', $trkfile;
                    next;
                }
                $trkfile
                  or Error("Expecting file name for -geotag option\n"),
                  $badCmd = 1, next;
                if ( HasWildcards($trkfile) ) {
                    my @trks;
                    if ( $^O eq 'MSWin32' and eval { require Win32::FindFile } )
                    {
                        @trks = FindFileWindows( $mt, $trkfile );
                    }
                    elsif ( eval { require File::Glob } ) {
                        @trks = File::Glob::bsd_glob($trkfile);
                    }
                    else {
                        @trks = glob($trkfile);
                    }
                    @trks
                      or Error("No matching file found for -geotag option\n"),
                      $badCmd = 1, next;
                    push @newValues, 'geotag=' . shift(@trks) while @trks > 1;
                    $trkfile = pop(@trks);
                }
                $_ = "geotag=$trkfile";
            }
            if ( /^h$/ or $a eq 'htmlformat' ) {
                require Image::ExifTool::HTML;
                $html = $escapeHTML = 1;
                $json = $xml        = 0;
                next;
            }
            ( /^H$/ or $a eq 'hex' ) and $showTagID = 'H', next;
            if (/^htmldump([-+]?\d+)?$/i) {
                $verbose = ( $verbose || 0 ) + 1;
                $html    = 2;
                $mt->Options( HtmlDumpBase => $1 ) if defined $1;
                next;
            }
            if (/^i(gnore)?$/i) {
                my $dir = shift;
                defined $dir
                  or Error("Expecting directory name for -i option\n"),
                  $badCmd = 1, next;
                $ignore{$dir} = 1;
                $dir eq 'HIDDEN' and $ignoreHidden = 1;
                next;
            }
            if (/^if(\d*)$/i) {
                my $cond = shift;
                my $fast = length($1) ? $1 : undef;
                defined $cond
                  or Error("Expecting expression for -if option\n"),
                  $badCmd = 1, next;
                if (   not @condition
                    or not defined $fast
                    or ( defined $fastCondition and $fastCondition > $fast ) )
                {
                    $fastCondition = $fast;
                }
                $cond =~ /^\s*(not\s*)\$ok\s*$/i
                  and ( $1 xor $rtnValPrev )
                  and $failCondition = 1;
                push @requestTags,
                  $cond =~ /\$\{?((?:[-_0-9A-Z]+:)*[-_0-9A-Z?*]+)/ig;
                push @condition, $cond;
                next;
            }
            /^(k|pause)$/i and $pause = 1, next;
            ( /^l$/ or $a eq 'long' ) and --$outFormat, next;
            ( /^L$/ or $a eq 'latin' )
              and $mt->Options( Charset => 'Latin' ), next;
            if ( $a eq 'lang' ) {
                $langOpt =
                  ( @ARGV and $ARGV[0] !~ /^(-|\xe2\x88\x92)/ ) ? shift : undef;
                if ($langOpt) {
                    $langOpt =~ tr/-A-Z/_a-z/;
                    $mt->Options( Lang => $langOpt );
                    next if $langOpt eq $mt->Options('Lang');
                }
                elsif ( not $pass ) {
                    push @nextPass, '-lang';
                    push @nextPass, $langOpt if defined $langOpt;
                    next;
                }
                my $langs = $quiet ? '' : "Available languages:\n";
                $langs .= "  $_ - $Image::ExifTool::langName{$_}\n"
                  foreach @Image::ExifTool::langs;
                $langs =~ tr/_/-/;
                $langs = Image::ExifTool::HTML::EscapeHTML($langs)
                  if $escapeHTML;
                $langs = $mt->Decode( $langs, 'UTF8' );
                $langOpt
                  and Error(
                    "Invalid or unsupported language '${langOpt}'.\n$langs"),
                  $badCmd = 1, next;
                print $langs;
                $helped = 1;
                next;
            }
            if ( $a eq 'listitem' ) {
                my $li = shift;
                defined $li and Image::ExifTool::IsInt($li)
                  or Warn("Expecting integer for -listItem option\n"), next;
                $mt->Options( ListItem => $li );
                $listItem = $li;
                next;
            }
            /^(m|ignoreminorerrors)$/i
              and $mt->Options( IgnoreMinorErrors => 1 ), next;
            /^(n|-printconv)$/i and $mt->Options( PrintConv => 0 ), next;
            /^(-n|printconv)$/i and $mt->Options( PrintConv => 1 ), next;
            $a eq 'nop'         and $helped = 1, next;
            if (/^o(ut)?$/i) {
                $outOpt = shift;
                defined $outOpt
                  or Error(
                    "Expected output file or directory name for -o option\n"),
                  $badCmd = 1, next;
                CleanFilename($outOpt);
                $vout = \*STDERR if $vout =~ /^-(\.\w+)?$/;
                next;
            }
            $a eq 'overwrite_original'          and $overwriteOrig = 1, next;
            $a eq 'overwrite_original_in_place' and $overwriteOrig = 2, next;
            $a eq 'plot'
              and require Image::ExifTool::Plot
              and $plot = Image::ExifTool::Plot->new, next;
            if ( /^p(-?)$/ or /^printformat(-?)$/i ) {
                my $fmt = shift;
                if ($pass) {
                    LoadPrintFormat( $fmt, $1 || $binaryOutput );
                    if ( not $useMWG
                        and grep /^([-_0-9A-Z]+:)*1?mwg:/i, @requestTags )
                    {
                        $useMWG = 1;
                        require Image::ExifTool::MWG;
                        Image::ExifTool::MWG::Load();
                    }
                }
                else {
                    push @nextPass, "-$_", $fmt;
                }
                next;
            }
            ( /^P$/ or $a eq 'preserve' ) and $preserveTime = 1, next;
            $a eq 'password' and $mt->Options( Password => shift ), next;
            if (/^progress(\d*)(:.*)?$/i) {
                $progressIncr = $1 || 1;
                $progressNext = 0;
                if ($2) {
                    $windowTitle = substr $2, 1;
                    $windowTitle = 'ExifTool %p%%' unless length $windowTitle;
                    $windowTitle =~ /%\d*[bpr]/ and $progress = 0
                      unless defined $progress;
                }
                else {
                    $progress = 1;
                    $verbose  = 0 unless defined $verbose;
                }
                $progressCount = 0;
                next;
            }
            /^purge(\d*)$/i
              and $purge = $1 || 1, Image::ExifTool::Purge($purge), next;
            /^q(uiet)?$/i and ++$quiet, next;
            /^r(ecurse)?(\.?)$/i and $recurse = ( $2 ? 2 : 1 ), next;
            if ( $a eq 'require' ) {
                my $ver = shift;
                unless ( defined $ver and Image::ExifTool::IsFloat($ver) ) {
                    Error("Expecting version number for -require option\n");
                    $badCmd = 1;
                    next;
                }
                unless ( $Image::ExifTool::VERSION >= $ver ) {
                    Error("Requires ExifTool version $ver or later\n");
                    $badCmd = 1;
                }
                next;
            }
            $a eq 'restore_original' and $deleteOrig = 0, next;
            ( /^S$/ or $a eq 'veryshort' ) and $outFormat += 2, next;
            /^s(hort)?(\d*)$/i
              and $outFormat = $2 eq '' ? $outFormat + 1 : $2, next;
            $a eq 'scanforxmp' and $mt->Options( ScanForXMP => 1 ), next;
            if (/^sep(arator)?$/i) {
                my $sep = $listSep = shift;
                defined $listSep
                  or Error("Expecting list item separator for -sep option\n"),
                  $badCmd = 1, next;
                $sep =~ s/\\(.)/$unescapeChar{$1}||$1/sge;
                ( defined $binSep ? $binTerm : $binSep ) = $sep;
                $mt->Options( ListSep => $listSep );
                $joinLists = 1;
                my $listSplit = quotemeta $listSep;
                $listSplit =~ s/(\\ )+/\\s\*/g;
                $listSplit = '\\s+' if $listSplit eq '\\s*';
                $mt->Options( ListSplit => $listSplit );
                next;
            }
            /^(-)?sort$/i and $sortOpt = $1 ? 0 : 1, next;
            if ( $a eq 'srcfile' ) {
                @ARGV or Warn("Expecting FMT for -srcfile option\n"), next;
                push @srcFmt, shift;
                next;
            }
            if ( $a eq 'stay_open' ) {
                my $arg = shift;
                defined $arg
                  or Warn("Expecting argument for -stay_open option\n"), next;
                if ( $arg =~ /^(1|true)$/i ) {
                    if ( not $stayOpen ) {
                        $stayOpen = 1;
                    }
                    elsif ( $stayOpen == 2 ) {
                        $stayOpen = 3;
                    }
                    else {
                        Warn "-stay_open already active\n";
                    }
                }
                elsif ( $arg =~ /^(0|false)$/i ) {
                    if ( $stayOpen >= 2 ) {
                        close STAYOPEN;
                        push @ARGV, @moreArgs;
                        undef @moreArgs;
                    }
                    elsif ( not $stayOpen ) {
                        Warn("-stay_open wasn't active\n");
                    }
                    $stayOpen = 0;
                }
                else {
                    Warn "Invalid argument for -stay_open\n";
                }
                next;
            }
            if (/^(-)?struct$/i) {
                $mt->Options( Struct => $1 ? 0 : 1 );
                next;
            }
            /^t(ab)?$/ and $tabFormat = 1, next;
            if ( /^T$/ or $a eq 'table' ) {
                $tabFormat = $forcePrint = 1;
                $outFormat += 2;
                ++$quiet;
                next;
            }
            if (/^(u)(nknown(2)?)?$/i) {
                my $inc = ( $3 or ( not $2 and $1 eq 'U' ) ) ? 2 : 1;
                $mt->Options( Unknown => $mt->Options('Unknown') + $inc );
                next;
            }
            if ( $a eq 'use' ) {
                my $module = shift;
                $module
                  or Error("Expecting module name for -use option\n"),
                  $badCmd = 1, next;
                lc $module eq 'mwg' and $useMWG = 1, next;
                $module =~ /[^\w:]/
                  and Error("Invalid module name: $module\n"), $badCmd = 1,
                  next;
                local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
                unless ( eval "require Image::ExifTool::$module"
                    or eval "require $module"
                    or eval "require '${module}'" )
                {
                    Error("Error using module $module\n");
                    $badCmd = 1;
                }
                next;
            }
            if ( $a eq 'userparam' ) {
                my $opt = shift;
                defined $opt
                  or Error("Expected parameter for -userParam option\n"),
                  $badCmd = 1, next;
                $opt =~ /=/ or $opt .= '=1';
                $mt->Options( UserParam => $opt );
                next;
            }
            if (/^v(erbose)?(\d*)$/i) {
                $verbose = ( $2 eq '' ) ? ( $verbose || 0 ) + 1 : $2;
                next;
            }
            if (/^(w|textout|tagout)([!+]*)$/i) {
                $textOut = shift || Warn("Expecting argument for -$_ option\n");
                my ( $t1, $t2 ) = ( $1, $2 );
                $textOverwrite = 0;
                $textOverwrite += 1 if $t2 =~ /!/;
                $textOverwrite += 2 if $t2 =~ /\+/;
                if ( $t1 ne 'W' and lc($t1) ne 'tagout' ) {
                    undef $tagOut;
                }
                elsif ( $textOverwrite >= 2
                    and $textOut !~ /%[-+]?\d*[.:]?\d*[lu]?[tgso]/ )
                {
                    $tagOut = 0;
                }
                else {
                    $tagOut = 1;
                }
                next;
            }
            if (/^(-?)(wext|tagoutext)$/i) {
                my $ext = shift;
                defined $ext
                  or Error("Expecting extension for -wext option\n"),
                  $badCmd = 1, next;
                my $flag = 1;
                $1 and $wext{'*'} = 1, $flag = -1;
                $ext =~ s/^\.//;
                $wext{ lc $ext } = $flag;
                next;
            }
            if ( $a eq 'wm' or $a eq 'writemode' ) {
                my $wm = shift;
                defined $wm
                  or Error("Expecting argument for -$_ option\n"), $badCmd = 1,
                  next;
                $wm =~ /^[wcg]*$/i
                  or Error("Invalid argument for -$_ option\n"), $badCmd = 1,
                  next;
                $mt->Options( WriteMode => $wm );
                next;
            }
            if ( /^x$/ or $a eq 'exclude' ) {
                my $tag = shift;
                defined $tag
                  or Error("Expecting tag name for -x option\n"), $badCmd = 1,
                  next;
                $tag =~ s/\ball\b/\*/ig;
                if ( not $tagsFrom ) {
                    push @exclude, $tag;
                }
                elsif ( $tagsFrom eq 'CSV' ) {
                    push @csvExclude, $tag;
                }
                else {
                    push @{ $setTags{$setTagsFile} }, "-$tag";
                }
                next;
            }
            ( /^X$/ or $a eq 'xmlformat' )
              and $xml = 1, $html = $json = 0, $mt->Options( Duplicates => 1 ),
              next;
            if ( $a eq 'php' ) {
                $json = 2;
                $html = $xml = 0;
                $mt->Options( Duplicates => 1 );
                next;
            }
            if (/^z(ip)?$/i) {
                $doUnzip = 1;
                $mt->Options( Compress => 1, XMPShorthand => 1 );
                $mt->Options( Compact  => 1 ) unless $mt->Options('Compact');
                next;
            }
            $_ eq '' and push( @files, '-' ), $srcStdin = 1, next;
            length $_ eq 1
              and $_ ne '*'
              and Error("Unknown option -$_\n"), $badCmd = 1, next;
            if (/^[^<]+(<?)=(.*)/s) {
                my $val = $2;
                if (    $1
                    and length($val)
                    and ( $val eq '@' or not defined FilenameSPrintf($val) ) )
                {
                    push @newValues, { SaveCount => ++$saveCount };
                }
                push @newValues, $_;
                if (/^([-_0-9A-Z]+:)*1?mwg:/i) {
                    $useMWG = 1;
                }
                elsif (/^([-_0-9A-Z]+:)*(filename|directory|testname)\b/i) {
                    $doSetFileName = 1;
                }
                elsif (/^([-_0-9A-Z]+:)*(geotag|geotime|geosync|geolocate)\b/i)
                {
                    if ( lc $2 eq 'geotime' ) {
                        $addGeotime = '';
                    }
                    else {
                        unshift @newValues, pop @newValues;
                        if (    lc $2 eq 'geotag'
                            and ( not defined $addGeotime or $addGeotime )
                            and length $val )
                        {
                            $addGeotime = ( $1 || '' )
                              . q[Geotime<${DateTimeOriginal#;$_=$self->GetValue('SubSecDateTimeOriginal','ValueConv') || $_}];
                        }
                    }
                }
            }
            else {
                if ( not $setTagsFile and $tagsFrom ne 'CSV' and /(<|>)/ ) {
                    AddSetTagsFile( $setTagsFile = '@' );
                    $tagsFrom = 'File';
                }
                if ( $tagsFrom eq 'CSV' ) {
                    my $lst = s/^-// ? \@csvExclude : \@tags;
                    push @$lst, $_;
                }
                elsif ($setTagsFile) {
                    push @{ $setTags{$setTagsFile} }, $_;
                    if ( $1 eq '>' ) {
                        $useMWG = 1 if /^(.*>\s*)?([-_0-9A-Z]+:)*1?mwg:/si;
                        if (/\b(filename|directory|testname)#?$/i) {
                            $doSetFileName = 1;
                        }
                        elsif (/\bgeotime#?$/i) {
                            $addGeotime = '';
                        }
                    }
                    else {
                        $useMWG = 1
                          if /^([^<]+<\s*(.*\$\{?)?)?([-_0-9A-Z]+:)*1?mwg:/si;
                        if (/^([-_0-9A-Z]+:)*(filename|directory|testname)\b/i)
                        {
                            $doSetFileName = 1;
                        }
                        elsif (/^([-_0-9A-Z]+:)*geotime\b/i) {
                            $addGeotime = '';
                        }
                    }
                }
                else {
                    my $lst = s/^-// ? \@exclude : \@tags;
                    Warn(qq(Invalid TAG name: "$_"\n))
                      unless /^([-_0-9A-Z*]+:)*([-_0-9A-Z*?]+)#?$/i;
                    push @$lst, $_;
                }
            }
        }
        else {
            unless ($pass) {
                push @nextPass, $_;
                next;
            }
            if ( $doGlob and HasWildcards($_) ) {
                if ( $^O eq 'MSWin32' and eval { require Win32::FindFile } ) {
                    push @files, FindFileWindows( $mt, $_ );
                }
                else {
                    push @files, File::Glob::bsd_glob($_);
                }
                $doGlob = 2;
            }
            else {
                push @files, $_;
                $srcStdin = 1 if $_ eq '-';
            }
        }
    }

    $mt->Options( UserParam => 'OK=' . ( not $rtnValPrev ) );

    $vout = \*STDERR if $srcStdin and ( $isWriting or @newValues );
    $mt->Options( TextOut => $vout ) if $vout eq \*STDERR;

    if ( $useMWG and not defined $mt->Options('CharsetEXIF') ) {
        $mt->Options( CharsetEXIF => 'UTF8' );
    }

    if ( not @files and not $outOpt and not @newValues ) {
        my $loc = $mt->Options('Geolocation');
        $loc and $loc ne '1' and push( @files, qq(\@JSON:{}) ), $geoOnly = 1;
    }

    unless ( ( @tags and not $outOpt ) or @files or @newValues or $geoOnly ) {
        if ( $doGlob and $doGlob == 2 ) {
            Error "No matching files\n";
            next;
        }
        $outOpt and Error("Nothing to write\n"), next;
        unless ($helped) {
            local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
            my $dummy = \*SAVEERR;
            unless ( $^O eq 'os2' ) {
                open SAVEERR, ">&STDERR";
                open STDERR,  '>/dev/null';
            }
            if ( system( 'perldoc', $0 ) ) {
                print "Syntax:  exiftool [OPTIONS] FILE\n\n";
                print
"Consult the exiftool documentation for a full list of options.\n";
            }
            unless ( $^O eq 'os2' ) {
                close STDERR;
                open STDERR, '>&SAVEERR';
            }
        }
        next;
    }

    if ( defined $deleteOrig and ( @newValues or @tags ) ) {
        if ( not @newValues ) {
            my $verb = $deleteOrig ? 'deleting' : 'restoring from';
            Error "Can't specify tags when $verb originals\n";
        }
        elsif ($deleteOrig) {
            Error "Can't use -delete_original when writing.\n";
            Error "Maybe you meant -overwrite_original ?\n";
        }
        else {
            Error "It makes no sense to use -restore_original when writing\n";
        }
        next;
    }

    if ( $overwriteOrig > 1 and $outOpt ) {
        Error "Can't overwrite in place when -o option is used\n";
        next;
    }

    if (
        ( $tagOut or defined $diff )
        and (  $csv
            or $json
            or %printFmt
            or $tabFormat
            or $xml
            or $plot
            or ( $verbose and $html ) )
      )
    {
        my $opt = $tagOut ? '-W' : '-diff';
        Error
"Sorry, $opt may not be combined with -csv, -htmlDump, -j, -p, -t or -X\n";
        next;
    }

    if ( $csv and $csv eq 'CSV' and not $isWriting ) {
        $json = 0;
        if ($textOut) {
            $textOut2 = $textOut;
            undef $textOut;
        }
        if ($binaryOutput) {
            $binaryOutput = 0;
            $setCharset   = 'default' unless defined $setCharset;
        }
        if (%printFmt) {
            Warn "The -csv option has no effect when -p is used\n";
            undef $csv;
        }
        require Image::ExifTool::XMP if $setCharset;
    }
    if ( $plot and $textOut ) {
        $textOut2 = $textOut;
        undef $textOut;
    }
    if ($textOut2) {
        if ( $textOverwrite > 1 ) {
            Error "Can not append to multi-file output format\n";
            undef $textOut2;
            next;
        }
        if ( not $textOverwrite and $mt->Exists( $textOut2, 1 ) ) {
            Error "Output file $textOut2 already exists\n";
            undef $textOut2;
            next;
        }
        CreateDirectory($textOut2);
        if ( $mt->Open( \*OUTFILE, $textOut2, '>' ) ) {
            close( \*OUTFILE );
            unlink($textOut2);
        }
        else {
            Error("Error creating $textOut2\n");
            undef $textOut2;
            next;
        }
    }

    if ( $escapeHTML or $json ) {
        $mt->Options( Charset => 'UTF8' ) if $json;
        $mt->Options( Escape => 'HTML' ) if $escapeHTML and not $xml;
    }
    elsif ( $escapeXML and not $xml ) {
        $mt->Options( Escape => 'XML' );
    }

    if ($sortOpt) {
        my $sort =
          ( $outFormat > 0 or $xml or $json or $csv or $plot )
          ? 'Tag'
          : 'Descr';
        $mt->Options( Sort => $sort, Sort2 => $sort );
    }

    if ( $mt->Options('Struct') and not $structOpt ) {
        $structOpt = $mt->Options('Struct');
        require 'Image/ExifTool/XMPStruct.pl';
    }

    if ($plot) {
        undef $joinLists;
        $mt->Options( List => 1 );
        $plot->Settings( $mt->Options('Plot') );
    }
    elsif ($xml) {
        require Image::ExifTool::XMP;
        my $charset = $mt->Options('Charset');
        my %encoding = (
            UTF8     => 'UTF-8',
            Latin    => 'windows-1252',
            Latin2   => 'windows-1250',
            Cyrillic => 'windows-1251',
            Greek    => 'windows-1253',
            Turkish  => 'windows-1254',
            Hebrew   => 'windows-1255',
            Arabic   => 'windows-1256',
            Baltic   => 'windows-1257',
            Vietnam  => 'windows-1258',
            MacRoman => 'macintosh',
        );
        unless ( $encoding{$charset} ) {
            $charset = 'UTF8';
            $mt->Options( Charset => $charset );
        }
        $fileHeader = "<?xml version='1.0' encoding='$encoding{$charset}'?>\n"
          . "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>\n";
        $fileTrailer = "</rdf:RDF>\n";
        $joinLists = 1 if $outFormat > 0;
        $mt->Options( List => 1 ) unless $joinLists;
        $showGroup = $allGroup = 1;

        $binaryOutput = ( $outFormat > 0 ? undef : 0 ) if $binaryOutput;
        $showTagID    = 'D' if $tabFormat and not $showTagID;
    }
    elsif ($json) {
        if ( $json == 1 ) {
            $fileHeader  = '[';
            $fileTrailer = "]\n";
        }
        else {
            $fileHeader  = 'Array(';
            $fileTrailer = ");\n";
        }
        if ($binaryOutput) {
            $binaryOutput = 0;
            require Image::ExifTool::XMP if $json == 1;
        }
        $mt->Options( List => 1 ) unless $joinLists;
        $showTagID = 'D' if $tabFormat and not $showTagID;
    }
    elsif ($structOpt) {
        $mt->Options( List => 1 );
    }
    else {
        $joinLists = 1;
    }

    if ($argFormat) {
        $outFormat = 3;
        $allGroup  = 1 if defined $showGroup;
    }

    if ( Image::ExifTool::IsPC() ) {
        tr/\\/\// foreach @files;
    }

    unless (@files) {
        unless ($outOpt) {
            if ( $doGlob and $doGlob == 2 ) {
                Error "No matching files\n";
            }
            else {
                Error "No file specified\n";
            }
            next;
        }
        push @files, '';
    }

    if ($verbose) {
        $disableOutput = 1  unless @tags or @exclude or $tagOut;
        undef $binaryOutput unless $tagOut;
        if ($html) {
            $html = 2;
            $mt->Options( HtmlDump => $verbose );
        }
        else {
            $mt->Options( Verbose => $verbose ) unless $tagOut;
        }
    }
    elsif ( defined $verbose ) {
        require FileHandle;
        STDOUT->autoflush(1);
        STDERR->autoflush(1);
    }

    my $needSave = 1;
    if (@newValues) {
        if ($addGeotime) {
            AddSetTagsFile( $setTagsFile = '@' )
              unless $setTagsFile and $setTagsFile eq '@';
            push @{ $setTags{$setTagsFile} }, $addGeotime;
            $verbose and print $vout qq(Using default "-$addGeotime"\n);
        }
        my %setTagsIndex;
        my %addDelOpt = (
            '+'            => 'AddValue',
            '-'            => 'DelValue',
            "\xe2\x88\x92" => 'DelValue'
        );
        $saveCount = 0;
        foreach (@newValues) {
            if ( ref $_ eq 'HASH' ) {
                if ( $$_{SaveCount} ) {
                    $saveCount = $mt->SaveNewValues();
                    $needSave  = 0;
                    push @dynamicFiles, \$csv if $$_{SaveCount} == $dbSaveCount;
                }
                next;
            }
            /(.*?)=(.*)/s or next;
            my ( $tag, $newVal ) = ( $1, $2 );
            $tag =~ s/\ball\b/\*/ig;
            $newVal eq '' and undef $newVal unless $tag =~ s/\^([-+]*)$/$1/;
            if ( $tag =~ /^(All)?TagsFromFile$/i ) {
                defined $newVal
                  or Error("Need file name for -tagsFromFile\n"), next Command;
                ++$isWriting;
                if (
                       $newVal eq '@'
                    or not defined FilenameSPrintf($newVal)
                    or
                    grep /\bfile\d+:/i, @{ $setTags{$newVal} }
                  )
                {
                    push @dynamicFiles, $newVal;
                    next;
                }
                unless ( $mt->Exists($newVal) or $newVal eq '-' ) {
                    Error
"File '${newVal}' does not exist for -tagsFromFile option\n";
                    next Command;
                }
                my $setTags = $setTags{$newVal};
                if ( $setTagsList{$newVal} ) {
                    my $i = $setTagsIndex{$newVal} || 0;
                    $setTagsIndex{$newVal} = $i + 1;
                    $setTags = $setTagsList{$newVal}[$i]
                      if $setTagsList{$newVal}[$i];
                }
                unless ( DoSetFromFile( $mt, $newVal, $setTags ) ) {
                    $rtnVal = 1;
                    next Command;
                }
                $needSave = 1;
                next;
            }
            my %opts = ( Shift => 0 );

            $opts{Protected} = 1 unless $tag =~ /[?*]/;

            if ( $tag =~ s/<// and defined $newVal ) {
                if ( defined FilenameSPrintf($newVal) ) {
                    SlurpFile( $newVal, \$newVal ) or next;
                }
                else {
                    $tag =~ s/([-+]|\xe2\x88\x92)$//
                      and $opts{ $addDelOpt{$1} } = 1;
                    my $result = Image::ExifTool::IsWritable($tag);
                    if ($result) {
                        $opts{ProtectSaved} = $saveCount;

                        push @dynamicFiles, [ $tag, $newVal, \%opts ];
                        ++$isWriting;
                    }
                    elsif ( defined $result ) {
                        Warn "Tag '${tag}' is not writable\n";
                    }
                    else {
                        Warn "Tag '${tag}' does not exist\n";
                    }
                    next;
                }
            }
            if ( $tag =~ s/([-+]|\xe2\x88\x92)$// ) {
                $opts{ $addDelOpt{$1} } = 1;

                $newVal = '' if $1 eq '-' and not defined $newVal;
            }
            if ( $escapeC and defined $newVal ) {
                $newVal =~
s/\\(x([0-9a-fA-F]{2})|.)/$2 ? chr(hex($2)) : $unescC{$1} || $1/seg;
            }
            my ( $rtn, $wrn ) = $mt->SetNewValue( $tag, $newVal, %opts );
            $needSave = 1;
            ++$isWriting if $rtn;
            $wrn and Warning( $mt, $wrn );
        }
        foreach (@exclude) {
            $mt->SetNewValue( $_, undef, Replace => 2 );
            $needSave = 1;
        }
        unless ( $isWriting or $outOpt or @tags ) {
            Error "Nothing to do.\n";
            next;
        }
    }
    elsif ( grep /^(\*:)?\*$/, @exclude ) {
        Error "All tags excluded -- nothing to do.\n";
        next;
    }
    if ($isWriting) {
        if ( defined $diff ) {
            Error "Can't use -diff option when writing tags\n";
            next;
        }
        elsif ($plot) {
            Error "Can't use -plot option when writing tags\n";
            next;
        }
        elsif ( @tags and not $outOpt and not $csv ) {
            my ( $tg, $s ) =
              @tags > 1 ? ( "$tags[0] ...", 's' ) : ( $tags[0], '' );
            Warn "Ignored superfluous tag name$s or invalid option$s: -$tg\n";
        }
    }
    $mt->SaveNewValues() if $outOpt or ( @dynamicFiles and $needSave );

    $multiFile = 1 if @files > 1;
    @exclude and $mt->Options( Exclude => \@exclude );

    undef $binaryOutput if $html;

    if ($binaryOutput) {
        $outFormat = 99;
        $mt->Options( PrintConv => 0 );
        unless ( $textOut or $binaryStdout ) {
            binmode(STDOUT);
            $binaryStdout = 1;
            $mt->Options( TextOut => ( $vout = \*STDERR ) );
        }
        undef $showGroup;
    }

    if (    defined $showGroup
        and not( @tags and ( $allGroup or $csv ) )
        and ( $sortOpt or not defined $sortOpt ) )
    {
        $mt->Options( Sort => "Group$showGroup" );
    }

    if ($textOut) {
        CleanFilename($textOut);

        $textOut = ".$textOut" unless $textOut =~ /[.%]/ or defined $tagOut;
    }

    if ($outOpt) {
        my $type = GetFileType($outOpt);
        if ($type) {
            my $canWrite = CanWrite($outOpt);
            unless ($canWrite) {
                if ( defined $canWrite and $canWrite eq '' ) {
                    $type = Image::ExifTool::GetFileExtension($outOpt);
                    $type = uc($outOpt) unless defined $type;
                }
                Error "Can't write $type files\n";
                next;
            }
            $scanWritable = $type unless CanCreate($type);
        }
        else {
            $scanWritable = 1;
        }
        $isWriting = 1;
    }
    elsif ( $isWriting or defined $deleteOrig ) {
        $scanWritable = 1;
    }

    $altEnc = $mt->Options('Charset');
    undef $altEnc if $altEnc eq 'UTF8';

    if ( not $altEnc and $mt->Options('Lang') ne 'en' ) {
        $fixLen = eval { require Unicode::GCString } ? 2 : 1;
    }

    if (@fileOrder) {
        my @allFiles;
        ProcessFiles( $mt, \@allFiles );
        my $sortTool = Image::ExifTool->new;
        $sortTool->Options( FastScan   => $fileOrderFast ) if $fileOrderFast;
        $sortTool->Options( PrintConv  => $mt->Options('PrintConv') );
        $sortTool->Options( Duplicates => 0 );
        my ( %sortBy, %isFloat, @rev, $file );
        push @rev, ( s/^-// ? 1 : 0 ) foreach @fileOrder;

        foreach $file (@allFiles) {
            my @tags;
            my $info =
              $sortTool->ImageInfo( Infile( $file, 1 ), @fileOrder, \@tags );
            foreach (@tags) {
                $_ = $$info{$_};
                defined $_ or $_ = '~', next;
                $isFloat{$_} = Image::ExifTool::IsFloat($_);
                s/(\d+)/(length($1) < 12 ? '0'x(12-length($1)) : '') . $1/eg
                  unless $isFloat{$_};
            }
            $sortBy{$file} = \@tags;
        }
        @files = sort {
            my ( $i, $cmp );
            for ( $i = 0 ; $i < @rev ; ++$i ) {
                my $u = $sortBy{$a}[$i];
                my $v = $sortBy{$b}[$i];
                if ( not $isFloat{$u} and not $isFloat{$v} ) {
                    $cmp = $u cmp $v;
                }
                elsif ( $isFloat{$u} and $isFloat{$v} ) {
                    $cmp = $u <=> $v;
                }
                else {
                    $cmp = $isFloat{$u} ? -1 : 1;
                }
                return $rev[$i] ? -$cmp : $cmp if $cmp;
            }
            return $a cmp $b;
        } @allFiles;
    }
    elsif ( defined $progress ) {
        my @allFiles;
        ProcessFiles( $mt, \@allFiles );
        @files = @allFiles;
    }
    $progressMax = scalar @files if defined $progress;

    my @dbKeys = keys %database;
    if (@dbKeys) {
        if ( eval { require Cwd } ) {
            undef $evalWarning;
            local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
            foreach (@dbKeys) {
                my $db = $database{$_};
                tr/\\/\// and $database{$_} = $db;
                $database{lc} = $db unless $database{lc};

                my $absPath = AbsPath($_);
                if ( defined $absPath ) {
                    $database{$absPath} = $db unless $database{$absPath};
                    if ( $verbose and $verbose > 1 ) {
                        print $vout
"Imported entry for '${_}' (full path: '${absPath}')\n";
                    }
                    $database{ lc $absPath } = $db
                      unless $database{ lc $absPath };
                }
                elsif ( $verbose and $verbose > 1 ) {
                    print $vout "Imported entry for '${_}' (no full path)\n";
                }
            }
        }
    }

    ProcessFiles($mt);

    Error "No file with specified extension\n" if $filtered and not $validFile;

    if ($textOut) {
        foreach ( keys %outTrailer ) {
            next unless $outTrailer{$_};
            if ( $mt->Open( \*OUTTRAIL, $_, '>>' ) ) {
                my $fp = \*OUTTRAIL;
                print $fp $outTrailer{$_};
                close $fp;
            }
            else {
                Error("Error appending to $_\n");
            }
        }
    }
    else {
        print $sectTrailer if $sectTrailer;
        print $fileTrailer if $fileTrailer and not $fileHeader;
        my ( $fp, $err );
        if ($textOut2) {
            if ( $mt->Open( \*OUTFILE, $textOut2, '>' ) ) {
                $fp = \*OUTFILE;
            }
            else {
                Error("Error creating $textOut2\n");
                $err = 1;
            }
        }
        unless ($err) {
            PrintCSV($fp) if $csv and not $isWriting;
            if ($plot) {
                $plot->Draw( $fp || \*STDOUT );
                if ( $$plot{Error} ) {
                    Error("Error: $$plot{Error}\n");
                    $err = 1;
                }
                elsif ( $$plot{Warn} ) {
                    Warn("Warning: $$plot{Warn}\n");
                }
            }
        }
        if ($fp) {
            close($fp) or $err = 1;
            if ($err) {
                $mt->Unlink($textOut2);
            }
            else {
                $created{$textOut2} = 1;
            }
        }
    }

    my $totWr =
      $countGoodWr +
      $countBadWr +
      $countSameWr +
      $countCopyWr +
      $countGoodCr +
      $countBadCr;

    if ( defined $deleteOrig ) {

        unless ($quiet) {
            printf "%5d directories scanned\n",    $countDir    if $countDir;
            printf "%5d directories created\n",    $countNewDir if $countNewDir;
            printf "%5d files failed condition\n", $countFailed if $countFailed;
            printf "%5d image files found\n",      $count;
        }
        if (@delFiles) {
            if ( $deleteOrig == 1 ) {
                printf '%5d originals will be deleted!  Are you sure [y/n]? ',
                  scalar(@delFiles);
                my $response = <STDIN>;
                unless ( $response =~ /^(y|yes)\s*$/i ) {
                    Warn "Originals not deleted.\n";
                    next;
                }
            }
            $countGoodWr = $mt->Unlink(@delFiles);
            $countBad    = scalar(@delFiles) - $countGoodWr;
        }
        if ($quiet) {
        }
        elsif ( $count and not $countGoodWr and not $countBad ) {
            printf "%5d original files found\n", $countGoodWr;
        }
        elsif ($deleteOrig) {
            printf "%5d original files deleted\n", $countGoodWr if $count;
            printf "%5d originals not deleted due to errors\n", $countBad
              if $countBad;
        }
        else {
            printf "%5d image files restored from original\n", $countGoodWr
              if $count;
            printf "%5d files not restored due to errors\n", $countBad
              if $countBad;
        }

    }
    elsif ( ( not $binaryStdout or $verbose ) and not $quiet ) {

        my $tot = $count + $countBad;
        if (   $countDir
            or $totWr
            or $countFailed
            or $tot > 1
            or $textOut
            or %countLink )
        {
            my $o = ( ( $html or $json or $xml or %printFmt or $csv or $plot )
                  and not $textOut ) ? \*STDERR : $vout;
            printf( $o "%5d directories scanned\n", $countDir ) if $countDir;
            printf( $o "%5d directories created\n", $countNewDir )
              if $countNewDir;
            printf( $o "%5d files failed condition\n", $countFailed )
              if $countFailed;
            printf( $o "%5d image files created\n", $countGoodCr )
              if $countGoodCr;
            printf( $o "%5d image files updated\n", $countGoodWr )
              if $totWr - $countGoodCr - $countBadCr - $countCopyWr;
            printf( $o "%5d image files unchanged\n", $countSameWr )
              if $countSameWr;
            printf( $o "%5d image files %s\n",
                $countCopyWr, $overwriteOrig ? 'moved' : 'copied' )
              if $countCopyWr;
            printf( $o "%5d files weren't updated due to errors\n",
                $countBadWr
            ) if $countBadWr;
            printf( $o "%5d files weren't created due to errors\n",
                $countBadCr
            ) if $countBadCr;
            printf( $o "%5d image files read\n", $count )
              if ( $tot + $countFailed ) > 1
              or ( $countDir and not $totWr );
            printf( $o "%5d files could not be read\n", $countBad )
              if $countBad;
            printf( $o "%5d output files created\n", scalar( keys %created ) )
              if $textOut or $textOut2;
            printf( $o "%5d output files appended\n", scalar( keys %appended ) )
              if %appended;
            printf( $o "%5d hard links created\n", $countLink{Hard} || 0 )
              if $countLink{Hard} or $countLink{BadHard};
            printf( $o "%5d hard links could not be created\n",
                $countLink{BadHard}
            ) if $countLink{BadHard};
            printf( $o "%5d symbolic links created\n", $countLink{Sym} || 0 )
              if $countLink{Sym} or $countLink{BadSym};
            printf( $o "%5d symbolic links could not be created\n",
                $countLink{BadSym}
            ) if $countLink{BadSym};
        }
    }

    if ( $countBadWr or $countBadCr or $countBad ) {
        $rtnVal = 1;
    }
    elsif ( $countFailed and not( $count or $totWr ) and not $rtnVal ) {
        $rtnVal = 2;
    }

    Image::ExifTool::Purge(0) if $purge;

    Cleanup();

}

close STAYOPEN if $stayOpen >= 2;

Exit $rtnValApp;

sub GetImageInfo($$) {
    my ( $et, $orig ) = @_;
    my ( @foundTags, @found2, $info, $info2, $et2, $file, $file2, $ind, $g8 );

    if ( defined $windowTitle ) {
        if ( $progressCount >= $progressNext ) {
            my $prog  = $progressMax ? "$progressCount/$progressMax" : '0/0';
            my $title = $windowTitle;
            my ( $num, $denom ) = split '/', $prog;
            my $frac = $num / ( $denom || 1 );
            my $n    = $title =~ s/%(\d+)b/%b/ ? $1 : 20;
            my $bar  = int( $frac * $n + 0.5 );
            my %lkup = (
                b   => ( 'I' x $bar ) . ( '.' x ( $n - $bar ) ),
                f   => $orig,
                p   => int( 100 * $frac + 0.5 ),
                r   => $prog,
                '%' => '%',
            );
            $title =~ s/%([%bfpr])/$lkup{$1}/eg;
            SetWindowTitle($title);

            if ( defined $progressMax ) {
                undef $progressNext;
            }
            else {
                $progressNext += $progressIncr;
            }
        }
        ++$progressCount unless defined $progressMax;
    }
    unless ( length $orig or $outOpt ) {
        Warn qq(Error: Zero-length file name - ""\n);
        ++$countBad;
        return;
    }
    if (@srcFmt) {
        my ( $fmt, $first );
        foreach $fmt (@srcFmt) {
            $file = $fmt eq '@' ? $orig : FilenameSPrintf( $fmt, $orig );
            $et->Exists($file) and undef($first), last;
            $verbose and print $vout "Source file $file does not exist\n";
            $first = $file unless defined $first;
        }
        $file = $first if defined $first;
        my ( $d, $f ) = Image::ExifTool::SplitFileName($orig);
        $et->Options( UserParam => "OriginalDirectory#=$d" );
        $et->Options( UserParam => "OriginalFileName#=$f" );
    }
    else {
        $file = $orig;
    }
    foreach $g8 ( sort keys %altFile ) {
        my $altName = $orig;
        unless ( $altFile{$g8} eq '@' ) {
            $altName =~ s/\$/\$\$/g;
            $altName = FilenameSPrintf( $altFile{$g8}, $altName );
        }
        $et->SetAlternateFile( $g8, $altName );
    }

    my $pipe = $file;
    if ($doUnzip) {
        if ( $file =~ /\.(gz|bz2)$/i ) {
            my $type = lc $1;
            if ( $file =~ /[^-_.'A-Za-z0-9\/\\]/ ) {
                Warn "Error: Insecure zip file name. Skipped\n";
                EFile($file);
                ++$countBad;
                return;
            }
            if ( $type eq 'gz' ) {
                $pipe = qq{gzip -dc "$file" |};
            }
            else {
                $pipe = qq{bzip2 -dc "$file" |};
            }
            $$et{TRUST_PIPE} = 1;
        }
    }
    if (@condition) {
        my $result;
        unless ($failCondition) {
            undef $evalWarning;
            local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };

            my ( %info, $condition );
            my $opts = {
                Duplicates  => 1,
                RequestTags => \@requestTags,
                Verbose     => 0,
                HtmlDump    => 0
            };
            $$opts{FastScan} = $fastCondition if defined $fastCondition;
            @foundTags = ( '*', @tags ) if @tags;
            $info =
              $et->ImageInfo( Infile( $pipe, $isWriting ), \@foundTags, $opts );
            foreach $condition (@condition) {
                my $cond =
                  $et->InsertTagValues( $condition, \@foundTags, \%info );
                {

                    package Image::ExifTool;

                    my $self = $et;
                    $result = eval $cond;

                    $@ and $evalWarning = $@;
                }
                if ($evalWarning) {
                    undef $result;
                    if ($verbose) {
                        chomp $evalWarning;
                        $evalWarning =~ s/ at \(eval .*//s;
                        Warn "Condition: $evalWarning - $file\n";
                    }
                }
                last unless $result;
            }
            undef @foundTags if $fastCondition;
        }
        if ($result) {
            undef $info unless $file eq '-' or $et->Exists($file);
        }
        else {
            Progress( $vout, "-------- $file (failed condition)" ) if $verbose;
            EFile( $file, 2 );
            ++$countFailed;
            return;
        }
        if ( $isWriting or $verbose or defined $fastCondition or defined $diff )
        {
            undef $info;
            --$$et{FILE_SEQUENCE};
        }
    }
    elsif ( $file =~ s/^(\@JSON:)(.*)/$1/ ) {
        my $dat = $2;
        $info = $et->ImageInfo( \$dat, \@foundTags );
        if ($geoOnly) {
            /^Geolocation/ or delete $$info{$_} foreach keys %$info;
            $file = ' ';
        }
    }
    if ( defined $deleteOrig ) {
        Progress( $vout, "======== $file" ) if defined $verbose;
        ++$count;
        my $original = "${file}_original";
        $et->Exists($original) or return;
        if ($deleteOrig) {
            $verbose and print $vout "Scheduled for deletion: $original\n";
            push @delFiles, $original;
        }
        elsif ( $et->Rename( $original, $file ) ) {
            $verbose and print $vout "Restored from $original\n";
            EFile( $file, 3 );
            ++$countGoodWr;
        }
        else {
            Warn "Error renaming $original\n";
            EFile($file);
            ++$countBad;
        }
        return;
    }
    ++$seqFileNum;
    my ($dir) = Image::ExifTool::SplitFileName($orig);
    $seqFileDir = $seqFileDir{$dir} = ( $seqFileDir{$dir} || 0 ) + 1;

    my $lineCount = 0;
    my ( $fp, $outfile, $append );
    if (    $textOut
        and ( $verbose or $et->Options('PrintCSV') )
        and not( $tagOut or defined $diff or $plot ) )
    {
        ( $fp, $outfile, $append ) = OpenOutputFile($orig);
        $fp or EFile($file), ++$countBad, return;
        $tmpText = $outfile unless $append;
        $et->Options( TextOut => $fp );
    }

    if ($isWriting) {
        Progress( $vout, "======== $file" ) if defined $verbose;
        SetImageInfo( $et, $file, $orig );
        $info = $et->GetInfo( 'Warning', 'Error' );
        PrintErrors( $et, $info, $file );
        if ( defined $outfile ) {
            undef $tmpText;
            close($fp);
            $et->Options( TextOut => $vout );
            if ( $info->{Error} ) {
                $et->Unlink($outfile);
            }
            elsif ($append) {
                $appended{$outfile} = 1 unless $created{$outfile};
            }
            else {
                $created{$outfile} = 1;
            }
        }
        return;
    }

    unless ( $file eq '-' or $et->Exists($file) or $info ) {
        Warn "Error: File not found - $file\n";
        FileNotFound($file);
        defined $outfile and close($fp), undef($tmpText), $et->Unlink($outfile);
        EFile($file);
        ++$countBad;
        return;
    }
    my $o;
    unless ( $binaryOutput
        or $textOut
        or %printFmt
        or $html > 1
        or $csv
        or $plot )
    {
        if ($html) {
            require Image::ExifTool::HTML;
            my $f = Image::ExifTool::HTML::EscapeHTML($file);
            print "<!-- $f -->\n";
        }
        elsif ( not( $json or $xml or defined $diff ) ) {
            $o = \*STDOUT if ( $multiFile and not $quiet ) or $progress;
        }
    }
    $o = \*STDERR                    if $progress and not $o;
    Progress( $o, "======== $file" ) if $o;
    if ($info) {
        if ( @tags and not %printFmt ) {
            @foundTags = @tags;
            $info      = $et->GetInfo( \@foundTags );
        }
    }
    else {
        my $oldDups = $et->Options('Duplicates');
        if (%printFmt) {
            $et->Options( Duplicates  => 1 );
            $et->Options( RequestTags => \@requestTags );
            if ( $printFmt{SetTags} ) {
                $$et{TAGS_FROM_FILE} = 1;
                $et->Options( MakerNotes  => 1 );
                $et->Options( Struct      => 2 );
                $et->Options( List        => 1 );
                $et->Options( CoordFormat => '%d %d %.8f' )
                  unless $et->Options('CoordFormat');
            }
        }
        else {
            @foundTags = @tags;
        }
        if ( defined $diff ) {
            $file2 = FilenameSPrintf( $diff, $orig );
            if ( $file eq $file2 ) {
                Warn "Error: Diffing file with itself - $file2\n";
                EFile($file);
                ++$countBad;
                return;
            }
            if ( $et->Exists($file2) ) {
                $showGroup = 1 unless defined $showGroup;
                $allGroup  = 1 unless defined $allGroup;
                $et->Options(
                    Duplicates => 1,
                    Sort       => "Group$showGroup",
                    Verbose    => 0
                );
                $et2 = Image::ExifTool->new;
                $et2->Options( %{ $$et{OPTIONS} } );
                $et2->Options( ListSep   => $$et{OPTIONS}{ListSep} );
                $et2->Options( ListSplit => $$et{OPTIONS}{ListSplit} );
                @found2 = @foundTags;
                $info2  = $et2->ImageInfo( $file2, \@found2 );
            }
            else {
                $info2 = { Error => "Diff file not found" };
            }
            if ( $$info2{Error} ) {
                Warn "Error: $$info2{Error} - $file2\n";
                EFile($file);
                ++$countBad;
                return;
            }
        }
        $info = $et->ImageInfo( Infile($pipe), \@foundTags );
        $et->Options( Duplicates => $oldDups );
    }

    if ($fp) {
        if ( defined $outfile ) {
            $et->Options( TextOut => \*STDOUT );
            undef $tmpText;
            if ( $info->{Error} ) {
                close($fp);
                $et->Unlink($outfile);
            }
            else {
                ++$lineCount;
            }
        }
        if ( $info->{Error} ) {
            Warn "Error: $$info{Error} - $file\n";
            EFile($file);
            ++$countBad;
            return;
        }
    }

    if ( $binaryOutput or not %$info ) {
        my $errs = $et->GetInfo( 'Warning', 'Error' );
        PrintErrors( $et, $errs, $file ) and EFile($file), $rtnVal = 1;
    }
    elsif ( $et->GetValue('Error')
        or ( $$et{Validate} and $et->GetValue('Warning') ) )
    {
        $rtnVal = 1;
    }

    unless ( defined $outfile or $tagOut ) {
        ( $fp, $outfile, $append ) = OpenOutputFile($orig);
        $fp or EFile($file), ++$countBad, return;
        $tmpText = $outfile if defined $outfile and not $append;
    }

    if ( defined $diff ) {
        my ( %done, %done2, $wasDiff, @diffs, @groupTags2 );
        my $v = $verbose || 0;
        print $fp "======== diff < $file > $file2\n";
        my ( $g2, $same ) = ( 0, 0 );
        for ( ; ; ) {
            my ( $g, $tag2, $i, $key, @dupl, $val2, $t2, $equal, %used );
            my $tag = shift @foundTags;
            if ( defined $tag ) {
                $done{$tag} = 1;
                $g = $et->GetGroup( $tag, $showGroup );
            }
            unless ($g) {
                for ( ; ; ) {
                    $tag2 = shift @found2;
                    defined $tag2 or $g = '', last;
                    $done2{$tag2}
                      or $g = $et2->GetGroup( $tag2, $showGroup ), last;
                }
            }
            if ( $g ne $g2 ) {
                foreach $t2 (@groupTags2) {
                    next if $done2{$t2};
                    my $val2 = $et2->GetValue($t2);
                    next unless defined $val2;
                    my $name =
                        $outFormat < 1
                      ? $et2->GetDescription($t2)
                      : GetTagName($t2);
                    my $len = LengthUTF8($name);
                    my $pad =
                      $outFormat < 2 ? ' ' x ( $len < 32 ? 32 - $len : 0 ) : '';
                    if ($allGroup) {
                        my $grp = "[$g2]";
                        $grp .= ' ' x ( 15 - length($grp) )
                          if length($grp) < 15 and $outFormat < 2;
                        push @diffs, sprintf "> %s %s%s: %s\n", $grp, $name,
                          $pad, Printable($val2);
                    }
                    else {
                        push @diffs, sprintf "> %s%s: %s\n", $name, $pad,
                          Printable($val2);
                    }
                    $done2{$t2} = 1;
                }
                my $str = '';
                $v
                  and ( $same or $v > 1 )
                  and $str =
                  "  ($same same tag" . ( $same == 1 ? '' : 's' ) . ')';
                if ( not $allGroup ) {
                    print $fp "---- $g2 ----$str\n"
                      if $g2 and ( $str or @diffs );
                }
                elsif ( $str and $g2 ) {
                    printf $fp "   %-13s%s\n", $g2, $str;
                }
                @diffs and print( $fp @diffs ), $wasDiff = 1, @diffs = ();
                last unless $g;
                ( $g2, $same ) = ( $g, 0 );
                @groupTags2 = ();
                push @groupTags2, $tag2 if defined $tag2;
                foreach $t2 (@found2) {
                    $done2{$t2}
                      or $g ne $et2->GetGroup( $t2, $showGroup )
                      or push @groupTags2, $t2;
                }
            }
            next unless defined $tag;
            my $val = $et->GetValue($tag);
            next unless defined $val;
            my $name = GetTagName($tag);
            my $desc = $outFormat < 1 ? $et->GetDescription($tag) : $name;
            my @tags2 = grep /^$name( |$)/, @groupTags2;
          T2: foreach $t2 (@tags2) {
                next if $done2{$t2};
                $tag2 = $t2;
                $val2 = $et2->GetValue($t2);
                next unless defined $val2;
                IsEqual( $val, $val2 ) and $equal = 1, last;
                if ( $$et{DUPL_TAG}{$name} and not @dupl ) {
                    for (
                        $i = 0, $key = $name ;
                        $i <= $$et{DUPL_TAG}{$name} ;
                        ++$i, $key = "$name ($i)"
                      )
                    {
                        push @dupl, $key
                          unless $done{$key}
                          or $g ne $et->GetGroup( $key, $showGroup );
                    }
                    @dupl =
                      sort { $$et{FILE_ORDER}{$a} <=> $$et{FILE_ORDER}{$b} }
                      @dupl
                      if @dupl > 1;
                }
                foreach (@dupl) {
                    next if $used{$_};
                    my $v = $et->GetValue($_);
                    next unless defined($v) and IsEqual( $v, $val2 );
                    $used{$_} = 1;
                    undef($tag2);
                    undef($val2);
                    next T2;
                }
                last;
            }
            if ($equal) {
                ++$same;
            }
            else {
                my $len = LengthUTF8($desc);
                my $pad =
                  $outFormat < 2 ? ' ' x ( $len < 32 ? 32 - $len : 0 ) : '';
                if ($allGroup) {
                    my $grp = "[$g]";
                    $grp .= ' ' x ( 15 - length($grp) )
                      if length($grp) < 15 and $outFormat < 2;
                    push @diffs, sprintf "< %s %s%s: %s\n", $grp, $desc, $pad,
                      Printable($val);
                    if ( defined $val2 ) {
                        $grp = ' ' x length($grp), $desc = ' ' x $len if $v < 3;
                        push @diffs, sprintf "> %s %s%s: %s\n", $grp, $desc,
                          $pad, Printable($val2);
                    }
                }
                else {
                    push @diffs, sprintf "< %s%s: %s\n", $desc, $pad,
                      Printable($val);
                    $desc = ' ' x $len if $v < 3;
                    push @diffs, sprintf "> %s%s: %s\n", $desc, $pad,
                      Printable($val2)
                      if defined $val2;
                }
            }
            $done2{$tag2} = 1 if defined $tag2;
        }
        print $fp "(no metadata differences)\n" unless $wasDiff;
        if ( defined $outfile ) {
            $created{$outfile} = 1;
            close($fp);
            undef $tmpText;
        }
        ++$count;
        return;
    }
    $comma = $outComma{$outfile} if $append and ( $textOverwrite & 0x02 );

    if (%printFmt) {
        my ( $type, @doc, $grp, $lastDoc, $cache );
        $fileTrailer = '';
        if ( $et->Options('ExtractEmbedded') ) {
            $lastDoc = $$et{DOC_COUNT} and $cache = {};
        }
        else {
            $lastDoc = 0;
        }
        for ( $doc[0] = 0 ; $doc[0] <= $lastDoc ; ) {
            my $doc = join '-', @doc;
            my ( $skipBody, $opt );
            foreach $type (qw(HEAD SECT IF BODY ENDS TAIL)) {
                my $prf = $printFmt{$type} or next;
                if ( $type eq 'HEAD' and defined $outfile ) {
                    next if $wroteHEAD{$outfile};
                    $wroteHEAD{$outfile} = 1;
                }
                next if $type eq 'BODY' and $skipBody;
                if (
                    $type eq 'IF'
                    or ( ( $doc[0] > 1 or @doc > 1 )
                        and not $$et{OPTIONS}{IgnoreMinorErrors} )
                  )
                {
                    $opt = 'Silent';
                }
                else {
                    $opt = 'Warn';
                }
                if ($lastDoc) {
                    if ($doc) {
                        next if $type eq 'HEAD' or $type eq 'TAIL';
                        $grp = "Doc$doc";
                    }
                    else {
                        $grp = 'Main';
                    }
                }
                my @lines;
                foreach (@$prf) {
                    my $line =
                      $et->InsertTagValues( $_, \@foundTags, $opt, $grp,
                        $cache );
                    if ( $type eq 'IF' ) {
                        $skipBody = 1 unless defined $line;
                    }
                    elsif ( defined $line ) {
                        push @lines, $line;
                    }
                }
                $lineCount += scalar @lines;
                if ( $type eq 'SECT' ) {
                    my $thisHeader = join '', @lines;
                    if ( $sectHeader and $sectHeader ne $thisHeader ) {
                        print $fp $sectTrailer if $sectTrailer;
                        undef $sectHeader;
                    }
                    $sectTrailer = '';
                    print $fp $sectHeader = $thisHeader unless $sectHeader;
                }
                elsif ( $type eq 'ENDS' ) {
                    $sectTrailer .= join '', @lines if defined $sectHeader;
                }
                elsif ( $type eq 'TAIL' ) {
                    $fileTrailer .= join '', @lines;
                }
                elsif (@lines) {
                    print $fp @lines;
                }
            }
            push @doc, 1;
            while ( @doc > 1 ) {
                my $nextDoc = join '-', @doc;
                last if $$et{HAS_DOC}{$nextDoc};
                pop @doc;
                ++$doc[-1];
            }
        }
        delete $printFmt{HEAD} unless defined $outfile;
        my $errs = $et->GetInfo( 'Warning', 'Error' );
        PrintErrors( $et, $errs, $file ) and EFile($file);
    }
    elsif ($plot) {
        my $tagExtra = $$et{TAG_EXTRA};
        my ( $tag, %docNum );
        foreach $tag ( keys %$info ) {
            next unless $$tagExtra{$tag} and $$tagExtra{$tag}{G3};
            $docNum{$tag} = $1 if $$tagExtra{$tag}{G3} =~ /(\d+)/;
        }
        $$plot{DocNum} = \%docNum;
        $$plot{EE}     = 1 if $et->Options('ExtractEmbedded');
        $plot->AddPoints( $info, \@foundTags );
    }
    elsif ( not $disableOutput ) {
        my ( $tag, $line, %noDups, %csvInfo, $bra, $ket, $sep, $quote );
        if ($fp) {
            if ($fileHeader) {
                print $fp $fileHeader
                  unless defined $outfile
                  and ( $created{$outfile} or $appended{$outfile} );
                undef $fileHeader unless $textOut;
            }
            if ($html) {
                print $fp "<table>\n";
            }
            elsif ($xml) {
                my $f = $file;
                CleanXML( \$f );
                print $fp "\n<rdf:Description rdf:about='${f}'";
                print $fp "\n  xmlns:et='http://ns.exiftool.org/1.0/'";
                print $fp
                  " et:toolkit='Image::ExifTool $Image::ExifTool::VERSION'";
                my ( %groups, @groups, $grp0, $grp1 );
                foreach $tag (@foundTags) {
                    ( $grp0, $grp1 ) = $et->GetGroup($tag);
                    unless ($grp1) {
                        next unless defined $forcePrint;
                        $grp0 = $grp1 = 'Unknown';
                    }
                    AddGroups( $$info{$tag}, $grp0, \%groups, \@groups )
                      if ref $$info{$tag};
                    next if $groups{$grp1};
                    $groups{$grp1} = $grp0;
                    push @groups, $grp1;
                }
                foreach $grp1 (@groups) {
                    my $grp = $groups{$grp1};
                    unless ($grp eq $grp1
                        and $grp =~ /^(ExifTool|File|Composite|Unknown)$/ )
                    {
                        $grp .= "/$grp1";
                    }
                    print $fp
                      "\n  xmlns:$grp1='http://ns.exiftool.org/$grp/1.0/'";
                }
                print $fp '>' if $outFormat < 1;
                $ind = $outFormat >= 0 ? ' ' : '   ';
            }
            elsif ($json) {
                ( $bra, $ket, $sep ) =
                  $json == 1 ? ( '{', '}', ':' ) : ( 'Array(', ')', ' =>' );
                $quote = 1
                  if $$et{OPTIONS}{StructFormat}
                  and $$et{OPTIONS}{StructFormat} eq 'JSONQ';
                print $fp ",\n" if $comma;
                print $fp qq($bra\n  "SourceFile"$sep ),
                  EscapeJSON( MyConvertFileName( $et, $file ), 1 );
                $comma = 1;
                $ind = ( defined $showGroup and not $allGroup ) ? '    ' : '  ';
            }
            elsif ($csv) {
                my $file2 = MyConvertFileName( $et, $file );
                $database{$file2} = \%csvInfo;
                push @csvFiles, $file2;
            }
        }
        my $noDups    = ( $json or ( $xml and $outFormat > 0 ) );
        my $printConv = $et->Options('PrintConv');
        my $lastGroup = '';
        my $i         = -1;
      TAG: foreach $tag (@foundTags) {
            ++$i;
            my $tagName = GetTagName($tag);
            my ( $group, $valList );
            my $val = $$info{$tag};
            $isBinary = ( ref $val eq 'SCALAR' and defined $binaryOutput );
            if ( ref $val ) {
                if (    defined $binaryOutput
                    and not $binaryOutput
                    and $$et{TAG_INFO}{$tag}{Protected} )
                {
                    my $lcTag = lc $tag;
                    $lcTag =~ s/ .*//;
                    next
                      unless $$et{REQ_TAG_LOOKUP}{$lcTag}
                      or ( $$et{OPTIONS}{RequestAll} || 0 ) > 2;
                }
                $val = ConvertBinary($val);
                next unless defined $val;
                if ( $structOpt and ref $val ) {
                    $val = Image::ExifTool::XMP::SerializeStruct( $et, $val )
                      unless $xml or $json;
                }
                elsif ( ref $val eq 'ARRAY' ) {
                    if ( defined $listItem ) {
                        $val = $$val[$listItem];
                    }
                    elsif ($binaryOutput) {
                        if ($tagOut) {
                            $valList = $val;
                            $val     = shift @$valList;
                        }
                        else {
                            $val = join defined $binSep ? $binSep : "\n", @$val;
                        }
                    }
                    elsif ($joinLists) {
                        $val = join $listSep, @$val;
                    }
                }
            }
            if ( not defined $val ) {
                next if $binaryOutput;
                if ( defined $forcePrint ) {
                    $val = $forcePrint;
                }
                elsif ( not $csv ) {
                    next;
                }
            }
            if ( defined $showGroup ) {
                $group = $et->GetGroup( $tag, $showGroup );
                next
                  if $noDups
                  and $tag =~ /^(.*?) ?\(/
                  and defined $$info{$1}
                  and $group eq $et->GetGroup( $1, $showGroup );
                if ( not $group and ( $xml or $json or $csv ) ) {
                    if ( $showGroup !~ /\b4\b/ ) {
                        $group = 'Unknown';
                    }
                    elsif ( $json and not $allGroup ) {
                        $group = 'Copy0';
                    }
                }
                if ( $fp and not( $allGroup or $csv ) ) {
                    if ( $lastGroup ne $group ) {
                        if ($html) {
                            my $cols = 1;
                            ++$cols if $outFormat == 0 or $outFormat == 1;
                            ++$cols if $showTagID;
                            print $fp
"<tr><td colspan=$cols bgcolor='#dddddd'>$group</td></tr>\n";
                        }
                        elsif ($json) {
                            print $fp "\n  $ket" if $lastGroup;
                            print $fp ','        if $lastGroup or $comma;
                            print $fp qq(\n  "$group"$sep $bra);
                            undef $comma;
                            undef %noDups;
                        }
                        else {
                            print $fp "---- $group ----\n";
                        }
                        $lastGroup = $group;
                    }
                    undef $group;
                }
            }
            elsif ($noDups) {
                next if $tag =~ /^(.*?) ?\(/ and defined $$info{$1};
            }

            ++$lineCount;

            for ( ; ; ) {
                if ($tagOut) {
                    my $ext = SuggestedExtension( $et, \$val, $tagName );
                    if ( %wext and ( $wext{$ext} || $wext{'*'} || -1 ) < 0 ) {
                        if ( $verbose and $verbose > 1 ) {
                            print $vout
                              "Not writing $ext output file for $tagName\n";
                        }
                        next TAG;
                    }
                    my @groups = $et->GetGroup($tag);
                    defined $outfile and close($fp), undef($tmpText);
                    my $org = $et->GetValue('OriginalRawFileName')
                      || $et->GetValue('OriginalFileName');
                    ( $fp, $outfile, $append ) =
                      OpenOutputFile( $orig, $tagName, \@groups, $ext, $org );
                    $fp or ++$countBad, next TAG;
                    $tmpText = $outfile unless $append;
                }
                if ($binaryOutput) {
                    print $fp $val;
                    print $fp $binTerm if defined $binTerm;
                    if ($tagOut) {
                        if ($append) {
                            $appended{$outfile} = 1 unless $created{$outfile};
                        }
                        else {
                            $created{$outfile} = 1;
                        }
                        close($fp);
                        undef $tmpText;
                        $verbose and print $vout "Wrote $tagName to $outfile\n";
                        undef $outfile;
                        undef $fp;
                        next TAG unless $valList and @$valList;
                        $val = shift @$valList;
                        next;
                    }
                    next TAG;
                }
                last;
            }
            if ($csv) {
                my $tn = $tagName;
                $tn .= '#' if $tag =~ /#/;
                my $gt = $group ? "$group:$tn" : $tn;
                my $lcTag = lc $gt;
                next if defined $csvInfo{$lcTag} and $tag =~ /\(/;
                $csvInfo{$lcTag} = $val;
                if ( defined $csvTags{$lcTag} ) {
                    $csvTags{$lcTag} = $gt if defined $$info{$tag};
                    next;
                }
                if (    $group
                    and defined $csvTags[$i]
                    and $csvTags[$i] =~ /^(.*):$tn$/i )
                {
                    next if $group eq 'Unknown';
                    if ( $1 eq 'unknown' ) {
                        delete $csvTags{ $csvTags[$i] };
                        $csvTags{$lcTag} = defined($val) ? $gt : '';
                        $csvTags[$i] = $lcTag;
                        next;
                    }
                }
                $csvTags{$lcTag} = defined($val) ? $gt : '';
                if ( @csvFiles == 1 ) {
                    push @csvTags, $lcTag;
                }
                elsif (@csvTags) {
                    undef @csvTags;
                }
                next;
            }

            my $desc = $outFormat > 0 ? $tagName : $et->GetDescription($tag);

            if ($xml) {
                my $tok = "$group:$tagName";
                if ( $outFormat > 0 ) {
                    if ( $structOpt and ref $val ) {
                        $val =
                          Image::ExifTool::XMP::SerializeStruct( $et, $val );
                    }
                    if ($escapeHTML) {
                        $val =~ tr/\0-\x08\x0b\x0c\x0e-\x1f/./;
                        Image::ExifTool::XMP::FixUTF8( \$val ) unless $altEnc;
                        $val =
                          Image::ExifTool::HTML::EscapeHTML( $val, $altEnc );
                    }
                    else {
                        CleanXML( \$val );
                    }
                    unless ( $noDups{$tok} ) {
                        $isCRLF and $val =~ s/\x0d\x0a/\x0a/g;
                        print $fp "\n $tok='${val}'";
                        $noDups{$tok} = 1;
                    }
                    next;
                }
                my ( $xtra, $valNum, $descClose );
                if ($showTagID) {
                    my ( $id, $lang ) = $et->GetTagID($tag);
                    if ( $id =~ /^\d+$/ ) {
                        $id = sprintf( "0x%.4x", $id ) if $showTagID eq 'H';
                    }
                    else {
                        $id = Image::ExifTool::XMP::FullEscapeXML($id);
                    }
                    $xtra = " et:id='${id}'";
                    $xtra .= " xml:lang='${lang}'" if $lang;
                }
                else {
                    $xtra = '';
                }
                if ($tabFormat) {
                    my $table = $et->GetTableName($tag);
                    my $index = $et->GetTagIndex($tag);
                    $xtra .= " et:table='${table}'";
                    $xtra .= " et:index='${index}'" if defined $index;
                }
                my $lastVal = $val;
                for ( $valNum = 0 ; $valNum < 2 ; ++$valNum ) {
                    $val = FormatXML( $val, $ind, $group );
                    $isCRLF and $val =~ s/\x0d\x0a/\x0a/g;
                    if ( $outFormat >= 0 ) {
                        print $fp "\n <$tok$xtra$val</$tok>";
                        last;
                    }
                    elsif ( $valNum == 0 ) {
                        CleanXML( \$desc );
                        if ($xtra) {
                            print $fp "\n <$tok>";
                            print $fp "\n  <rdf:Description$xtra>";
                            $descClose = "\n  </rdf:Description>";
                        }
                        else {
                            print $fp "\n <$tok rdf:parseType='Resource'>";
                            $descClose = '';
                        }
                        print $fp "\n   <et:desc>$desc</et:desc>";
                        if ($printConv) {
                            print $fp "\n   <et:prt$val</et:prt>";
                            $val = $et->GetValue( $tag, 'ValueConv' );
                            $val = '' unless defined $val;
                            next unless IsEqual( $val, $lastVal, 1 );
                            print $fp "$descClose\n </$tok>";
                            last;
                        }
                    }
                    print $fp "\n   <et:val$val</et:val>";
                    print $fp "$descClose\n </$tok>";
                    last;
                }
                next;
            }
            elsif ($json) {
                my $tok = $allGroup ? "$group:$tagName" : $tagName;
                next if $noDups{$tok};
                $noDups{$tok} = 1;
                print $fp ',' if $comma;
                print $fp qq(\n$ind"$tok"$sep );
                if ( $showTagID or $outFormat < 0 ) {
                    $val = { val => $val };
                    if ($showTagID) {
                        my ( $id, $lang ) = $et->GetTagID($tag);
                        $id = sprintf( '0x%.4x', $id )
                          if $showTagID eq 'H' and $id =~ /^\d+$/;
                        $$val{lang} = $lang if $lang;
                        $$val{id}   = $id;
                    }
                    if ($tabFormat) {
                        $$val{table} = $et->GetTableName($tag);
                        my $index = $et->GetTagIndex($tag);
                        $$val{index} = $index if defined $index;
                    }
                    if ( $outFormat < 0 ) {
                        $$val{desc} = $desc;
                        if ($printConv) {
                            my $num = $et->GetValue( $tag, 'ValueConv' );
                            $$val{num} = $num
                              if defined $num
                              and not IsEqual( $num, $$val{val}, 1 );
                        }
                        my $ex = $$et{TAG_EXTRA}{$tag};
                        $$val{'fmt'} = $$ex{G6} if defined $$ex{G6};
                        if ( defined $$ex{BinVal} ) {
                            my $max =
                              ( $$et{OPTIONS}{LimitLongValues} - 5 ) / 3;
                            if ( $max >= 0
                                and length( $$ex{BinVal} ) > int($max) )
                            {
                                $max = int $max;
                                $$val{'hex'} = join ' ',
                                  unpack( "(H2)$max", $$ex{BinVal} ), '[...]';
                            }
                            else {
                                $$val{'hex'} = join ' ', unpack '(H2)*',
                                  $$ex{BinVal};
                            }
                        }
                        $$val{rat} = $$ex{Rational}
                          if defined $$ex{Rational} and $$et{OPTIONS}{SaveBin};
                    }
                }
                FormatJSON( $fp, $val, $ind, $quote );
                $comma = 1;
                next;
            }
            my $id;
            if ($showTagID) {
                $id = $et->GetTagID($tag);
                if ( $id =~ /^(\d+)(\.\d+)?$/ ) {
                    $id = sprintf( "0x%.4x", $1 ) if $showTagID eq 'H';
                }
                else {
                    $id = '-';
                }
            }

            if ($escapeC) {
                $val =~
                  s/([\0-\x1f\\\x7f])/$escC{$1} || sprintf('\x%.2x', ord $1)/eg;
            }
            else {
                $val =~ tr/\x01-\x1f\x7f/./;
                $val =~ s/\x00//g;
                $val =~ s/\s+$//;
            }

            if ($html) {
                print $fp "<tr>";
                print $fp "<td>$group</td>" if defined $group;
                print $fp "<td>$id</td>"    if $showTagID;
                print $fp "<td>$desc</td>"  if $outFormat <= 1;
                print $fp "<td>$val</td></tr>\n";
            }
            else {
                my $buff = '';
                if ($tabFormat) {
                    $buff = "$group\t" if defined $group;
                    $buff .= "$id\t"   if $showTagID;
                    if ( $outFormat <= 1 ) {
                        $buff .= "$desc\t$val\n";
                    }
                    elsif ( defined $line ) {
                        $line .= "\t$val";
                    }
                    else {
                        $line = $val;
                    }
                }
                elsif ( $outFormat < 0 ) {
                    $buff = "[$group] " if defined $group;
                    $buff .= "$id " if $showTagID;
                    $buff .= "$desc\n      $val\n";
                }
                elsif ( $outFormat == 0 or $outFormat == 1 ) {
                    my $wid;
                    my $len = 0;
                    if ( defined $group ) {
                        $buff = sprintf( "%-15s ", "[$group]" );
                        $len  = 16;
                    }
                    if ($showTagID) {
                        $wid = ( $showTagID eq 'D' ) ? 5 : 6;
                        $len += $wid + 1;
                        ( $wid = $len - length($buff) - 1 ) < 1 and $wid = 1;
                        $buff .= sprintf "%${wid}s ", $id;
                    }
                    $wid = 32 - ( length($buff) - $len );
                    my $padLen = $wid - LengthUTF8($desc);
                    $padLen = 0 if $padLen < 0;
                    $buff .= $desc . ( ' ' x $padLen ) . ": $val\n";
                }
                elsif ( $outFormat == 2 ) {
                    $buff = "[$group] " if defined $group;
                    $buff .= "$id " if $showTagID;
                    $buff .= "$tagName: $val\n";
                }
                elsif ($argFormat) {
                    $buff = '-';
                    $buff    .= "$group:" if defined $group;
                    $tagName .= '#'       if $tag =~ /#/;
                    $buff    .= "$tagName=$val\n";
                }
                else {
                    $buff = "$group " if defined $group;
                    $buff .= "$id " if $showTagID;
                    $buff .= "$val\n";
                }
                print $fp $buff;
            }
            if ($tagOut) {
                if ($append) {
                    $appended{$outfile} = 1 unless $created{$outfile};
                }
                else {
                    $created{$outfile} = 1;
                }
                close($fp);
                undef $tmpText;
                $verbose and print $vout "Wrote $tagName to $outfile\n";
                undef $outfile;
                undef $fp;
            }
        }
        if ($fp) {
            if ($html) {
                print $fp "</table>\n";
            }
            elsif ($xml) {
                print $fp $outFormat < 1 ? "\n</rdf:Description>\n" : "/>\n";
            }
            elsif ($json) {
                print $fp "\n  $ket" if $lastGroup;
                print $fp "\n$ket";
                $comma = 1;
            }
            elsif ( $tabFormat and $outFormat > 1 ) {
                print $fp "$line\n" if defined $line;
            }
        }
    }
    if ( defined $outfile ) {
        if ( $textOverwrite & 0x02 ) {
            $outComma{$outfile}                                    = $comma;
            $outTrailer{$outfile}                                  = '';
            $outTrailer{$outfile} .= $sectTrailer and $sectTrailer = ''
              if $sectTrailer;
            $outTrailer{$outfile} .= $fileTrailer if $fileTrailer;
        }
        else {
            print $fp $sectTrailer and $sectTrailer = '' if $sectTrailer;
            print $fp $fileTrailer                       if $fileTrailer;
        }
        close($fp);
        undef $tmpText;
        if ($lineCount) {
            if ($append) {
                $appended{$outfile} = 1 unless $created{$outfile};
            }
            else {
                $created{$outfile} = 1;
            }
        }
        else {
            $et->Unlink($outfile) unless $append;
        }
        undef $comma;
    }
    ++$count;
}

sub SetImageInfo($$$) {
    my ( $et,      $file,     $orig ) = @_;
    my ( $outfile, $restored, $isTemporary, $isStdout, $outType, $tagsFromSrc );
    my ( $hardLink, $symLink, $testName,    $sameFile );
    my $infile = $file;

    if ( defined $tmpFile ) {
        $et->Unlink($tmpFile);
        undef $tmpFile;
    }
    delete $$et{VALUE}{Error};
    delete $$et{VALUE}{Warning};

    if ( defined $outOpt ) {
        if ( $outOpt =~ /^-(\.\w+)?$/ ) {
            $outType  = GetFileType($outOpt) if $1;
            $outfile  = '-';
            $isStdout = 1;
        }
        else {
            $outfile = FilenameSPrintf( $outOpt, $orig );
            if ( $outfile eq '' ) {
                Warn
                  "Error: Can't create file with zero-length name from $orig\n";
                EFile($infile);
                ++$countBadCr;
                return 0;
            }
        }
        if (
            not $isStdout
            and ( ( $et->IsDirectory($outfile) and not $listDir )
                or $outfile =~ /\/$/ )
          )
        {
            $outfile .= '/' unless $outfile =~ /\/$/;
            my $name = $file;
            $name =~ s/^.*\///s;
            $outfile .= $name;
        }
        else {
            my $srcType = GetFileType($file) || '';
            $outType or $outType = GetFileType($outfile);
            if (    $outType
                and ( $srcType ne $outType or $outType eq 'ICC' )
                and $file ne '-' )
            {
                unless ( CanCreate($outType) ) {
                    my $what = $srcType ? 'other types' : 'scratch';
                    WarnOnce "Error: Can't create $outType files from $what\n";
                    EFile($infile);
                    ++$countBadCr;
                    return 0;
                }
                if ( $file ne '' ) {
                    $et->RestoreNewValues() unless $restored;
                    $restored = 1;
                    my @setTags = @tags;
                    foreach (@exclude) {
                        push @setTags, "-$_";
                    }
                    my %forceCopy = (
                        ICC => 'ICC_Profile',
                        VRD => 'CanonVRD',
                        DR4 => 'CanonDR4',
                    );
                    push @setTags, $forceCopy{$outType} if $forceCopy{$outType};
                    if ( not %setTags or ( @setTags and not $setTags{'@'} ) ) {
                        return 0 unless DoSetFromFile( $et, $file, \@setTags );
                    }
                    elsif (@setTags) {
                        push @setTags, @{ $setTags{'@'} };
                        $tagsFromSrc = \@setTags;
                    }
                    $file = '';
                }
            }
        }
        unless ($isStdout) {
            $outfile = NextUnusedFilename($outfile);
            if ( $et->Exists( $outfile, 1 ) and not $doSetFileName ) {
                Warn "Error: '${outfile}' already exists - $infile\n";
                EFile($infile);
                ++$countBadWr;
                return 0;
            }
        }
    }
    elsif ( $file eq '-' ) {
        $isStdout = 1;
    }
    if (@dynamicFiles) {
        $et->RestoreNewValues() unless $restored;
        my ( $dyFile, %setTagsIndex );
        foreach $dyFile (@dynamicFiles) {
            if ( not ref $dyFile ) {
                my ( $fromFile, $setTags );
                if ( $dyFile eq '@' ) {
                    $fromFile = $orig;
                    $setTags  = $tagsFromSrc || $setTags{$dyFile};
                }
                else {
                    $fromFile = FilenameSPrintf( $dyFile, $orig );
                    defined $fromFile
                      or EFile($infile), ++$countBadWr, return 0;
                    $setTags = $setTags{$dyFile};
                }
                if ( $setTagsList{$dyFile} ) {
                    my $i = $setTagsIndex{$dyFile} || 0;
                    $setTagsIndex{$dyFile} = $i + 1;
                    $setTags = $setTagsList{$dyFile}[$i]
                      if $setTagsList{$dyFile}[$i];
                }
                return 0 unless DoSetFromFile( $et, $fromFile, $setTags );
            }
            elsif ( ref $dyFile eq 'ARRAY' ) {
                my $fname = FilenameSPrintf( $$dyFile[1], $orig );
                my ( $buff, $rtn, $wrn );
                my $opts = $$dyFile[2];
                if ( defined $fname and SlurpFile( $fname, \$buff ) ) {
                    $verbose
                      and print $vout "Reading $$dyFile[0] from $fname\n";
                    ( $rtn, $wrn ) =
                      $et->SetNewValue( $$dyFile[0], $buff, %$opts );
                    $wrn and Warn "$wrn\n";
                }
                $rtn
                  or $et->SetNewValue(
                    $$dyFile[0], undef,
                    Replace      => 2,
                    ProtectSaved => $$opts{ProtectSaved}
                  );
                next;
            }
            elsif ( ref $dyFile eq 'SCALAR' ) {
                my ( $f, $found, $csvTag, $tg, $csvEtPrt, $csvEtVal );
                undef $evalWarning;
                local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
                my $old = $et->Options('Charset');
                $et->Options( Charset => 'UTF8' ) if $csv eq 'JSON';
                foreach $f ( '*', MyConvertFileName( $et, $file ) ) {
                    my $csvInfo = $database{$f};
                    unless ($csvInfo) {
                        next if $f eq '*';
                        my $absPath = AbsPath($f);
                        if ( defined $absPath and $database{$absPath} ) {
                            $csvInfo = $database{$absPath};
                        }
                        elsif ( $database{ lc $f } ) {
                            $csvInfo = $database{ lc $f };
                        }
                        elsif ( defined $absPath and $database{ lc $absPath } )
                        {
                            $csvInfo = $database{ lc $absPath };
                        }
                        else {
                            next;
                        }
                    }
                    $found = 1;
                    if ($verbose) {
                        print $vout "Setting new values from $csv database\n";
                        print $vout 'Including tags: ', join( ' ', @tags ), "\n"
                          if @tags;
                        print $vout 'Excluding tags: ',
                          join( ' ', @csvExclude ), "\n"
                          if @csvExclude;
                    }
                    if (@tags) {
                        $csvEtPrt = Image::ExifTool->new unless $csvEtPrt;
                        foreach $csvTag ( OrderedKeys($csvInfo) ) {
                            next
                              if $csvTag =~
/^([-_0-9A-Z]+:)*(SourceFile|Directory|FileName)$/i;
                            my @grps = split /:/, $csvTag;
                            my $name = pop @grps;
                            unshift @grps, 'All' while @grps < 2;
                            if ( $name =~ s/#$// ) {
                                $csvEtVal = Image::ExifTool->new
                                  unless $csvEtVal;
                                $csvEtVal->FoundTag( $name, $$csvInfo{$csvTag},
                                    @grps );
                            }
                            else {
                                $csvEtPrt->FoundTag( $name, $$csvInfo{$csvTag},
                                    @grps );
                            }
                        }
                        next;
                    }
                    my @exclTags = @csvExclude;
                    foreach (@exclTags) {
                        tr/-0-9a-zA-Z_:#?*//dc;
                        s/(^|:)(all:)+/$1/ig;
                        s/(^|:)all(#?)$/$1*$2/i;
                        tr/?/./;
                        s/\*/.*/g;
                    }
                    foreach $csvTag ( OrderedKeys($csvInfo) ) {
                        next
                          if $csvTag =~
                          /^([-_0-9A-Z]+:)*(SourceFile|Directory|FileName)$/i;
                        if (@exclTags) {
                            my ( $exclTag, $exclGrp, $excluded );
                          ExclMatch: foreach $exclTag (@exclTags) {
                                if ( $exclTag =~ /:/ ) {
                                    next unless $csvTag =~ /:/;
                                    my @csvGrps  = split /:/, $csvTag;
                                    my @exclGrps = split /:/, $exclTag;
                                    my $exclName = pop @exclGrps;
                                    next unless pop(@csvGrps) =~ /^$exclName$/i;
                                    foreach $exclGrp (@exclGrps) {
                                        next ExclMatch
                                          unless grep /^$exclGrp$/i, @csvGrps;
                                    }
                                    $excluded = 1;
                                    last;
                                }
                                $csvTag =~ /^([-_0-9A-Z]+:)*$exclTag$/i
                                  and $excluded = 1, last;
                            }
                            next if $excluded;
                        }
                        my ( $rtn, $wrn ) = $et->SetNewValue(
                            $csvTag, $$csvInfo{$csvTag},
                            Protected    => 1,
                            AddValue     => $dbAdd,
                            ProtectSaved => $dbSaveCount
                        );
                        $wrn and Warn "$wrn\n" if $verbose;
                    }
                }
                if ($csvEtPrt) {
                    my @excl = map "-$_", @csvExclude;
                    my $opts = { AddValue => $dbAdd, Replace => 0 };
                    $et->SetNewValuesFromFile( $csvEtPrt, $opts, @tags, @excl );
                    if ($csvEtVal) {
                        $$opts{Type} = 'ValueConv';
                        $et->SetNewValuesFromFile( $csvEtVal, $opts, @tags,
                            @excl );
                    }
                }
                $et->Options( Charset => $old ) if $csv eq 'JSON';
                unless ($found) {
                    Warn("No SourceFile '${file}' in imported $csv database\n");
                    my $absPath = AbsPath($file);
                    Warn("(full path: '${absPath}')\n")
                      if defined $absPath and $absPath ne $file;
                    return 0;
                }
            }
        }
    }
    if ($isStdout) {
        $outfile = \*STDOUT;
        unless ($binaryStdout) {
            binmode(STDOUT);
            $binaryStdout = 1;
        }
    }
    else {
        $hardLink = $et->GetNewValues('HardLink');
        $symLink  = $et->GetNewValues('SymLink');
        $testName = $et->GetNewValues('TestName');
        $hardLink = FilenameSPrintf( $hardLink, $orig ) if defined $hardLink;
        $symLink  = FilenameSPrintf( $symLink,  $orig ) if defined $symLink;
        my $newFileName = $et->GetNewValues('FileName');
        my $newDir      = $et->GetNewValues('Directory');
        if ( defined $newFileName and not length $newFileName ) {
            Warning( $et, "New file name is empty - $infile" );
            undef $newFileName;
        }
        if ( defined $testName ) {
            my $err;
            $err = "You shouldn't write FileName or Directory with TestFile"
              if defined $newFileName or defined $newDir;
            $err = "The -o option shouldn't be used with TestFile"
              if defined $outfile;
            $err
              and Warn("Error: $err - $infile\n"), EFile($infile),
              ++$countBadWr, return 0;
            $testName = FilenameSPrintf( $testName, $orig );
            $testName = Image::ExifTool::GetNewFileName( $file, $testName )
              if $file ne '';
        }
        if (   defined $newFileName
            or defined $newDir
            or ( $doSetFileName and defined $outfile ) )
        {
            if ($newFileName) {
                $newFileName = FilenameSPrintf( $newFileName, $orig );
                if ( defined $outfile ) {
                    $outfile =
                      Image::ExifTool::GetNewFileName( $file, $outfile )
                      if $file ne '';
                    $outfile =
                      Image::ExifTool::GetNewFileName( $outfile, $newFileName );
                }
                elsif ( $file ne '' ) {
                    $outfile =
                      Image::ExifTool::GetNewFileName( $file, $newFileName );
                }
            }
            if ($newDir) {
                $newDir  = FilenameSPrintf( $newDir, $orig );
                $outfile = Image::ExifTool::GetNewFileName(
                    defined $outfile ? $outfile : $file, $newDir );
            }
            $outfile = NextUnusedFilename( $outfile, $infile );
            if ( $et->Exists( $outfile, 1 ) ) {
                if ( $infile eq $outfile ) {
                    undef $outfile;

                }
                elsif ( $et->IsSameFile( $infile, $outfile ) ) {
                    $sameFile = $outfile;
                }
                else {
                    Warn "Error: '${outfile}' already exists - $infile\n";
                    EFile($infile);
                    ++$countBadWr;
                    return 0;
                }
            }
        }
        if ( defined $outfile ) {
            defined $verbose and print $vout "'${infile}' --> '${outfile}'\n";
            CreateDirectory($outfile);
            $tmpFile = $outfile if defined $outOpt;
        }
        unless ( defined $tmpFile ) {
            my ( $numSet, $numPseudo ) = $et->CountNewValues();
            if ( $numSet != $numPseudo and $et->IsDirectory($file) ) {
                print $vout "Can't write real tags to a directory - $infile\n"
                  if defined $verbose;
                $numSet = $numPseudo;
            }
            if ( $et->Exists($file) ) {
                unless ($numSet) {
                    print $vout "Nothing changed in $file\n"
                      if defined $verbose;
                    EFile( $infile, 1 );
                    ++$countSameWr;
                    return 1;
                }
            }
            elsif ( CanCreate($file) ) {
                if ( $numSet == $numPseudo ) {
                    Warn("Error: Nothing to write - $file\n");
                    EFile( $infile, 1 );
                    ++$countBadWr;
                    return 0;
                }
                unless ( defined $outfile ) {
                    $outfile = $file;
                    $file    = '';
                }
            }
            else {
                Warn "Error: File not found - $file\n";
                EFile($infile);
                FileNotFound($file);
                ++$countBadWr;
                return 0;
            }
            if ( $numSet == $numPseudo ) {
                my ( $r0, $r1, $r2, $r3 ) = ( 0, 0, 0, 0 );
                if ( defined $outfile ) {
                    $r0   = $et->SetFileName( $file, $outfile );
                    $file = $$et{NewName} if $r0 > 0;
                }
                unless ( $r0 < 0 ) {
                    $r1 =
                      $et->SetFileModifyDate( $file, undef, 'FileCreateDate' );
                    $r2 = $et->SetFileModifyDate($file);
                    $r3 = $et->SetSystemTags($file);
                }
                if ( $r0 > 0 or $r1 > 0 or $r2 > 0 or $r3 > 0 ) {
                    EFile( $infile, 3 );
                    ++$countGoodWr;
                }
                elsif ( $r0 < 0 or $r1 < 0 or $r2 < 0 or $r3 < 0 ) {
                    EFile($infile);
                    ++$countBadWr;
                    return 0;
                }
                else {
                    EFile( $infile, 1 );
                    ++$countSameWr;
                }
                if (   defined $hardLink
                    or defined $symLink
                    or defined $testName )
                {
                    DoHardLink( $et, $file, $hardLink, $symLink, $testName );
                }
                return 1;
            }
            if ( not defined $outfile or defined $sameFile ) {
                $outfile = "${file}_exiftool_tmp";
                if ( $et->Exists($outfile) ) {
                    Warn("Error: Temporary file already exists: $outfile\n");
                    EFile($infile);
                    ++$countBadWr;
                    return 0;
                }
                $isTemporary = 1;
            }
            $tmpFile = $outfile;
        }
    }
    my $success = $et->WriteInfo( Infile($file), $outfile, $outType );

    if ( $success
        and ( defined $hardLink or defined $symLink or defined $testName ) )
    {
        my $src = defined $outfile ? $outfile : $file;
        DoHardLink( $et, $src, $hardLink, $symLink, $testName );
    }

    my ( $aTime, $mTime, $cTime, $doPreserve );
    $doPreserve = $preserveTime unless $file eq '';
    if ( $doPreserve and $success ) {
        ( $aTime, $mTime, $cTime ) = $et->GetFileTime($file);
        undef $cTime if $$et{WRITTEN}{FileCreateDate};
        if ( $$et{WRITTEN}{FileModifyDate} or $doPreserve == 2 ) {
            if ( defined $cTime ) {
                undef $aTime;
                undef $mTime;
            }
            else {
                undef $doPreserve;
            }
        }
    }

    if ( $success == 1 ) {
        if ( defined $tmpFile ) {
            if ( $et->Exists($file) ) {
                $et->SetFileTime( $tmpFile, $aTime, $mTime, $cTime )
                  if $doPreserve;
                if ($isTemporary) {
                    $et->CopyFileAttrs( $file, $outfile );
                    my $original = "${file}_original";
                    if ( not $overwriteOrig and not $et->Exists($original) ) {
                        if ( not $et->Rename( $file, $original )
                            or $et->Exists($file) )
                        {
                            Error "Error renaming $file\n";
                            return 0;
                        }
                    }
                    my $dstFile = defined $sameFile ? $sameFile : $file;
                    if ( $overwriteOrig > 1 ) {
                        my ( $err, $buff );
                        my $newFile = $tmpFile;
                        $et->Open( \*NEW_FILE, $newFile )
                          or Error("Error opening $newFile\n"), return 0;
                        binmode(NEW_FILE);

                        $critical = 1;
                        undef $tmpFile;
                        if ( $et->Open( \*ORIG_FILE, $file, '+<' ) ) {
                            binmode(ORIG_FILE);
                            while ( read( NEW_FILE, $buff, 65536 ) ) {
                                print ORIG_FILE $buff or $err = 1;
                            }
                            close(NEW_FILE);
                            eval { truncate( ORIG_FILE, tell(ORIG_FILE) ) }
                              or $err = 1;
                            close(ORIG_FILE) or $err = 1;
                            if ($err) {
                                Warn "Couldn't overwrite in place - $file\n";
                                unless (
                                    $et->Rename( $newFile, $file )
                                    or (    $et->Unlink($file)
                                        and $et->Rename( $newFile, $file ) )
                                  )
                                {
                                    Error("Error renaming $newFile to $file\n");
                                    undef $critical;
                                    SigInt() if $interrupted;
                                    return 0;
                                }
                            }
                            else {
                                $et->SetFileModifyDate( $file, $cTime,
                                    'FileCreateDate', 1 );
                                $et->SetFileModifyDate( $file, $mTime,
                                    'FileModifyDate', 1 );
                                $et->Unlink($newFile);
                                if ($doPreserve) {
                                    $et->SetFileTime( $file, $aTime, $mTime,
                                        $cTime );
                                    $preserveTime{$file} =
                                      [ $aTime, $mTime, $cTime ];
                                }
                            }
                            EFile( $infile, 3 );
                            ++$countGoodWr;
                        }
                        else {
                            close(NEW_FILE);
                            Warn "Error opening $file for writing\n";
                            EFile($infile);
                            $et->Unlink($newFile);
                            ++$countBadWr;
                        }
                        undef $critical;
                        SigInt() if $interrupted;

                    }
                    elsif ( $et->Rename( $tmpFile, $dstFile ) ) {
                        EFile( $infile, 3 );
                        ++$countGoodWr;
                    }
                    else {
                        my $newFile = $tmpFile;
                        undef $tmpFile;

                        if ( not $et->Unlink($file) ) {
                            Warn "Error renaming temporary file to $dstFile\n";
                            EFile($infile);
                            $et->Unlink($newFile);
                            ++$countBadWr;
                        }
                        elsif ( not $et->Rename( $newFile, $dstFile ) ) {
                            Warn "Error renaming temporary file to $dstFile\n";
                            EFile($infile);
                            ++$countBadWr;
                        }
                        else {
                            EFile( $infile, 3 );
                            ++$countGoodWr;
                        }
                    }
                }
                elsif ($overwriteOrig) {
                    EFile( $infile, 3 );
                    $et->Unlink($file) or Warn "Error erasing original $file\n";
                    ++$countGoodWr;
                }
                else {
                    EFile( $infile, 4 );
                    ++$countGoodCr;
                }
            }
            else {
                EFile( $infile, 4 );
                ++$countGoodCr;
            }
        }
        else {
            EFile( $infile, 3 );
            ++$countGoodWr;
        }
    }
    elsif ($success) {
        EFile( $infile, 1 );
        if ($isTemporary) {
            $et->Unlink($tmpFile);
            ++$countSameWr;
        }
        else {
            $et->SetFileTime( $outfile, $aTime, $mTime, $cTime ) if $doPreserve;
            if ($overwriteOrig) {
                $et->Unlink($file) or Warn "Error erasing original $file\n";
            }
            ++$countCopyWr;
        }
        print $vout "Nothing changed in $file\n" if defined $verbose;
    }
    else {
        EFile($infile);
        $et->Unlink($tmpFile) if defined $tmpFile;
        ++$countBadWr;
    }
    undef $tmpFile;
    return $success;
}

sub DoHardLink($$$$$) {
    my ( $et, $src, $hardLink, $symLink, $testName ) = @_;
    if ( defined $hardLink ) {
        $hardLink = NextUnusedFilename($hardLink);
        if ( $et->SetFileName( $src, $hardLink, 'Link' ) > 0 ) {
            $countLink{Hard} = ( $countLink{Hard} || 0 ) + 1;
        }
        else {
            $countLink{BadHard} = ( $countLink{BadHard} || 0 ) + 1;
        }
    }
    if ( defined $symLink ) {
        $symLink = NextUnusedFilename($symLink);
        if ( $et->SetFileName( $src, $symLink, 'SymLink' ) > 0 ) {
            $countLink{Sym} = ( $countLink{Sym} || 0 ) + 1;
        }
        else {
            $countLink{BadSym} = ( $countLink{BadSym} || 0 ) + 1;
        }
    }
    if ( defined $testName ) {
        $testName = NextUnusedFilename( $testName, $src );
        if ( $usedFileName{$testName} ) {
            $et->Warn("File '${testName}' would exist");
        }
        elsif (
            $et->SetFileName( $src, $testName, 'Test',
                $usedFileName{$testName} ) == 1
          )
        {
            $usedFileName{$testName} = 1;
            $usedFileName{$src}      = 0;
        }
    }
}

sub CleanXML($) {
    my $strPt = shift;
    $$strPt =~ tr/\0-\x08\x0b\x0c\x0e-\x1f/./;
    Image::ExifTool::XMP::FixUTF8($strPt) unless $altEnc;
    $$strPt = Image::ExifTool::XMP::EscapeXML($$strPt);
}

sub EncodeXML($) {
    my $strPt = shift;
    if ( $$strPt =~ /[\0-\x08\x0b\x0c\x0e-\x1f]/
        or ( not $altEnc and Image::ExifTool::IsUTF8($strPt) < 0 ) )
    {
        $$strPt = Image::ExifTool::XMP::EncodeBase64($$strPt);
        return 'http://www.w3.org/2001/XMLSchema#base64Binary';
    }
    elsif ($escapeHTML) {
        $$strPt = Image::ExifTool::HTML::EscapeHTML( $$strPt, $altEnc );
    }
    else {
        $$strPt = Image::ExifTool::XMP::EscapeXML($$strPt);
    }
    return '';
}

sub FormatXML($$$) {
    local $_;
    my ( $val, $ind, $grp ) = @_;
    my $gt = '>';
    if ( ref $val eq 'ARRAY' ) {
        my $val2 = "\n$ind <rdf:Bag>";
        foreach (@$val) {
            $val2 .=
              "\n$ind  <rdf:li" . FormatXML( $_, "$ind  ", $grp ) . "</rdf:li>";
        }
        $val = "$val2\n$ind </rdf:Bag>\n$ind";
    }
    elsif ( ref $val eq 'HASH' ) {
        $gt = " rdf:parseType='Resource'>";
        my $val2 = '';
        foreach ( OrderedKeys($val) ) {
            my ( $ns, $tg ) = ( $grp, $_ );
            if (/^(.*?):(.*)/) {
                if ( $grp eq 'JSON' ) {
                    $tg =~ tr/:/_/;
                }
                else {
                    ( $ns, $tg ) = ( $1, $2 );
                }
            }
            my $name;
            foreach $name ( $ns, $tg ) {
                $name =~ tr/-_A-Za-z0-9.//dc;
                $name = '_' . $name if $name !~ /^[_A-Za-z]/;
            }
            my $tok = $ns . ':' . $tg;
            $val2 .=
                "\n$ind <$tok"
              . FormatXML( $$val{$_}, "$ind ", $grp )
              . "</$tok>";
        }
        $val = "$val2\n$ind";
    }
    else {
        my $enc = EncodeXML( \$val );
        $gt = " rdf:datatype='${enc}'>\n" if $enc;
    }
    return $gt . $val;
}

sub EscapeJSON($;$) {
    my ( $str, $quote ) = @_;
    unless ($quote) {
        return lc($str) if $str =~ /^(true|false)$/i and $json < 2;
        return $str
          if $str =~ /^-?(\d|[1-9]\d{1,14})(\.\d{1,16})?(e[-+]?\d{1,3})?$/i;
    }
    if (    $json < 2
        and defined $binaryOutput
        and Image::ExifTool::IsUTF8( \$str ) < 0 )
    {
        return '"base64:' . Image::ExifTool::XMP::EncodeBase64( $str, 1 ) . '"';
    }
    $str =~ s/(["\t\n\r\\])/\\$jsonChar{$1}/sg;
    if ( $json < 2 ) {
        $str =~ tr/\0//d;

        $str =~ s/([\0-\x1f\x7f])/sprintf("\\u%.4X",ord $1)/sge;
        Image::ExifTool::XMP::FixUTF8( \$str ) unless $altEnc;
    }
    else {
        $str =~ s/\0+$// unless $isBinary;

        $str =~ s/\$/\\\$/sg;
        $str =~ s/([\0-\x1f\x7f])/sprintf("\\x%.2X",ord $1)/sge;
    }
    return '"' . $str . '"';
}

sub FormatJSON($$$;$) {
    local $_;
    my ( $fp, $val, $ind, $quote ) = @_;
    my $comma;
    if ( not ref $val ) {
        print $fp EscapeJSON( $val, $quote );
    }
    elsif ( ref $val eq 'ARRAY' ) {
        if ( $joinLists and not ref $$val[0] ) {
            print $fp EscapeJSON( join( $listSep, @$val ), $quote );
        }
        else {
            my ( $bra, $ket ) = $json == 1 ? ( '[', ']' ) : ( 'Array(', ')' );
            print $fp $bra;
            foreach (@$val) {
                print $fp ',' if $comma;
                FormatJSON( $fp, $_, $ind, $quote );
                $comma = 1,;
            }
            print $fp $ket,;
        }
    }
    elsif ( ref $val eq 'HASH' ) {
        my ( $bra, $ket, $sep ) =
          $json == 1 ? ( '{', '}', ':' ) : ( 'Array(', ')', ' =>' );
        print $fp $bra;
        foreach ( OrderedKeys($val) ) {
            print $fp ',' if $comma;
            my $key = EscapeJSON( $_, 1 );
            print $fp qq(\n$ind  $key$sep );
            if (    $showTagID
                and $_ eq 'id'
                and $showTagID eq 'H'
                and $$val{$_} =~ /^\d+\.\d+$/ )
            {
                print $fp qq{"$$val{$_}"};
            }
            else {
                FormatJSON( $fp, $$val{$_}, "$ind  ", $quote );
            }
            $comma = 1,;
        }
        print $fp "\n$ind$ket",;
    }
    else {
        print $fp '"<err>"';
    }
}

sub FormatCSV($) {
    my $val = shift;
    if (
        $setCharset
        and (
            $val =~ /[^\x09\x0a\x0d\x20-\x7e\x80-\xff]/
            or
            ( $setCharset eq 'UTF8' and Image::ExifTool::IsUTF8( \$val ) < 0 )
        )
      )
    {
        $val = 'base64:' . Image::ExifTool::XMP::EncodeBase64( $val, 1 );
    }
    $val = qq{"$val"}
      if $val =~ s/"/""/g
      or $val =~ /(^\s+|\s+$)/
      or $val =~ /[\n\r]|\Q$csvDelim/;
    return $val;
}

sub PrintCSV(;$) {
    my $fp = shift || \*STDOUT;
    my ( $file, $lcTag, @tags );

    @csvTags or @csvTags = sort keys %csvTags;
    foreach $lcTag (@csvTags) {
        push @tags, FormatCSV( $csvTags{$lcTag} ) if $csvTags{$lcTag};
    }
    print $fp join( $csvDelim, 'SourceFile', @tags ), "\n";
    my $empty = defined($forcePrint) ? $forcePrint : '';
    foreach $file (@csvFiles) {
        my @vals    = ( FormatCSV($file) );
        my $csvInfo = $database{$file};
        foreach $lcTag (@csvTags) {
            next unless $csvTags{$lcTag};
            my $val = $$csvInfo{$lcTag};
            defined $val or push( @vals, $empty ), next;
            push @vals, FormatCSV($val);
        }
        print $fp join( $csvDelim, @vals ), "\n";
    }
}

sub AddGroups($$$$) {
    my ( $val, $grp, $groupHash, $groupList ) = @_;
    my ( $key, $val2 );
    if ( ref $val eq 'HASH' ) {
        foreach $key ( sort keys %$val ) {
            if ( $key =~ /^(.*?):/ and not $$groupHash{$1} and $grp ne 'JSON' )
            {
                $$groupHash{$1} = $grp;
                push @$groupList, $1;
            }
            AddGroups( $$val{$key}, $grp, $groupHash, $groupList )
              if ref $$val{$key};
        }
    }
    elsif ( ref $val eq 'ARRAY' ) {
        foreach $val2 (@$val) {
            AddGroups( $val2, $grp, $groupHash, $groupList ) if ref $val2;
        }
    }
}

sub ConvertBinary($) {
    my $obj = shift;
    my ( $key, $val );
    if ( ref $obj eq 'HASH' ) {
        foreach $key ( keys %$obj ) {
            next unless ref $$obj{$key};
            $$obj{$key} = ConvertBinary( $$obj{$key} );
            return undef unless defined $$obj{$key};
        }
    }
    elsif ( ref $obj eq 'ARRAY' ) {
        foreach $val (@$obj) {
            next unless ref $val;
            $val = ConvertBinary($val);
            return undef unless defined $val;
        }
    }
    elsif ( ref $obj eq 'SCALAR' ) {
        return undef if $noBinary;
        if ( defined $binaryOutput ) {
            $obj = $$obj;
            if (
                $json == 1
                and ( $obj =~ /[^\x09\x0a\x0d\x20-\x7e\x80-\xf7]/
                    or Image::ExifTool::IsUTF8( \$obj ) < 0 )
              )
            {
                $obj =
                  'base64:' . Image::ExifTool::XMP::EncodeBase64( $obj, 1 );
            }
        }
        else {
            my $bOpt = $html ? '' : ', use -b option to extract';
            if ( $$obj =~ /^Binary data \d+ bytes$/ ) {
                $obj = "($$obj$bOpt)";
            }
            else {
                $obj = '(Binary data ' . length($$obj) . " bytes$bOpt)";
            }
        }
    }
    return $obj;
}

sub IsEqual($$;$) {
    my ( $a, $b, $trueScalar ) = @_;
    return 1 if $a eq $b;
    if ( ref $a eq 'SCALAR' ) {
        return 1 if $trueScalar;
        return 1 if ref $b eq 'SCALAR' and $$a eq $$b;
        return 0;
    }
    if ( ref $a eq 'HASH' and ref $b eq 'HASH' ) {
        return 0 if scalar( keys %$a ) != scalar( keys %$b );
        my $key;
        foreach $key ( keys %$a ) {
            return 0 unless IsEqual( $$a{$key}, $$b{$key}, $trueScalar );
        }
    }
    else {
        return 0 if ref $a ne 'ARRAY' or ref $b ne 'ARRAY' or @$a != @$b;
        my $i;
        for ( $i = 0 ; $i < scalar(@$a) ; ++$i ) {
            return 0 unless IsEqual( $$a[$i], $$b[$i], $trueScalar );
        }
    }
    return 1;
}

sub Printable($) {
    my $val = shift;
    if ( ref $val ) {
        if ($structOpt) {
            require Image::ExifTool::XMP;
            $val = Image::ExifTool::XMP::SerializeStruct( $mt, $val );
        }
        elsif ( ref $val eq 'ARRAY' ) {
            $val = join( $listSep, @$val );
        }
        elsif ( ref $val eq 'SCALAR' ) {
            $val = '(Binary data ' . length($$val) . ' bytes)';
        }
    }
    if ($escapeC) {
        $val =~ s/([\0-\x1f\\\x7f])/$escC{$1} || sprintf('\x%.2x', ord $1)/eg;
    }
    else {
        $val =~ tr/\x01-\x1f\x7f/./;
        $val =~ s/\x00//g;
        $val =~ s/\s+$//;
    }
    return $val;
}

sub LengthUTF8($) {
    my $str = shift;
    return length $str unless $fixLen;
    local $SIG{'__WARN__'} = sub { };
    if ( not $$mt{OPTIONS}{EncodeHangs} and eval { require Encode } ) {
        $str = Encode::decode_utf8($str);
    }
    else {
        $str = pack( 'U0C*', unpack 'C*', $str );
    }
    my $len;
    if ( $fixLen == 1 ) {
        $len = length $str;
    }
    else {
        my $gcstr = eval { Unicode::GCString->new($str) };
        if ($gcstr) {
            $len = $gcstr->columns;
        }
        else {
            $len = length $str;
            delete $SIG{'__WARN__'};
            Warning( $mt,
                'Unicode::GCString problem.  Columns may be misaligned' );
            $fixLen = 1;
        }
    }
    return $len;
}

sub AddSetTagsFile($;$) {
    my ( $setFile, $opts ) = @_;
    if ( $setTags{$setFile} ) {
        $setTagsList{$setFile} or $setTagsList{$setFile} = [];
        push @{ $setTagsList{$setFile} }, $setTags{$setFile};
    }
    $setTags{$setFile} = [];

    push @newValues, { SaveCount => ++$saveCount }, "TagsFromFile=$setFile";
    $opts or $opts = {};
    $$opts{ProtectSaved} = $saveCount;
    push @{ $setTags{$setFile} }, $opts;
}

sub Infile($;$) {
    my ( $file, $bufferStdin ) = @_;
    if ( $file eq '-' and ( $bufferStdin or $rafStdin ) ) {
        if ($rafStdin) {
            $rafStdin->Seek(0);
        }
        elsif ( open RAF_STDIN, '-' ) {
            $rafStdin = File::RandomAccess->new( \*RAF_STDIN );
            $rafStdin->BinMode();
        }
        return $rafStdin if $rafStdin;
    }
    return $file;
}

sub Warning($$) {
    my ( $et, $str ) = @_;
    my $noWarn = $et->Options('NoWarning');
    if ( not defined $noWarn or not eval { $str =~ /$noWarn/ } ) {
        Warn "Warning: $str\n";
    }
}

sub DoSetFromFile($$$) {
    local $_;
    my ( $et, $file, $setTags ) = @_;
    $verbose and print $vout "Setting new values from $file\n";
    my $info   = $et->SetNewValuesFromFile( Infile( $file, 1 ), @$setTags );
    my $numSet = scalar( keys %$info );
    if ( $$info{Error} ) {
        my @warns = grep /^(Error|Warning)\b/, keys %$info;
        $numSet -= scalar(@warns);
        my $err = $$info{Error};
        delete $$info{$_} foreach @warns;
        my $noWarn = $et->Options('NoWarning');
        $$info{Warning} = $err
          unless defined $noWarn and eval { $err =~ /$noWarn/ };
    }
    elsif ( $$info{Warning} ) {
        my $warns = 1;
        ++$warns while $$info{"Warning ($warns)"};
        $numSet -= $warns;
    }
    PrintErrors( $et, $info, $file ) and EFile($file), ++$countBadWr, return 0;
    Warning( $et, "No writable tags set from $file" ) unless $numSet;
    return 1;
}

sub CleanFilename($) {
    $_[0] =~ tr/\\/\// if Image::ExifTool::IsPC();
}

sub HasWildcards($) {
    my $path = shift;

    return 0 if $^O eq 'MSWin32' and $path =~ m{^[\\/]{2}\?[\\/]};
    return $path =~ /[*?]/;
}

sub CheckUTF8($$) {
    my ( $file, $enc ) = @_;
    my $isUTF8 = 0;
    if ( $file =~ /[\x80-\xff]/ ) {
        $isUTF8 = Image::ExifTool::IsUTF8( \$file );
        if ( $isUTF8 < 0 ) {
            if ($enc) {
                Warn("Invalid filename encoding for $file\n");
            }
            elsif ( not defined $enc ) {
                WarnOnce(
qq{FileName encoding not specified.  Use "-charset FileName=CHARSET"\n}
                );
            }
        }
    }
    return $isUTF8;
}

sub SetWindowTitle($) {
    my $title = shift;
    if ( $curTitle ne $title ) {
        $curTitle = $title;
        if ( $^O eq 'MSWin32' ) {
            $title =~ tr(-_a-zA-Z0-9 \(\)[]{}%.+/:;,=?*!@#$~')()dc;
            eval { system qq{title $title} };
        }
        else {
            printf STDERR "\033]0;%s\007", $title;
        }
    }
}

sub ProcessFiles($;$) {
    my ( $et, $list ) = @_;
    my $enc = $et->Options('CharsetFileName');
    my $file;
    foreach $file (@files) {
        $et->Options( CharsetFileName => 'UTF8' ) if $utf8FileName{$file};
        if ( defined $progressMax ) {
            unless ( defined $progressNext ) {
                $progressNext = $progressCount + $progressIncr;
                $progressNext -= $progressNext % $progressIncr;
                $progressNext = $progressMax if $progressNext > $progressMax;
            }
            ++$progressCount;
            if ($progress) {
                if ( $progressCount >= $progressNext ) {
                    $progStr = " [$progressCount/$progressMax]";
                }
                else {
                    undef $progStr;
                }
            }
        }
        if ( $et->IsDirectory($file) and not $listDir ) {
            $multiFile = $validFile = 1;
            ScanDir( $et, $file, $list );
        }
        elsif ( $filterFlag and not AcceptFile($file) ) {
            if ( $et->Exists($file) ) {
                $filtered = 1;
                Progress( $vout, "-------- $file (wrong extension)" )
                  if $verbose;
            }
            else {
                Error "Error: File not found - $file\n";
                FileNotFound($file);
            }
        }
        else {
            $validFile = 1;
            if ($list) {
                push( @$list, $file );
            }
            else {
                if (%endDir) {
                    my ( $d, $f ) = Image::ExifTool::SplitFileName($file);
                    next if $endDir{$d};
                }
                GetImageInfo( $et, $file );
                Image::ExifTool::Purge($purge) if $purge;
                $end and Warn("End called - $file\n");
                if ($endDir) {
                    Warn("EndDir called - $file\n");
                    my ( $d, $f ) = Image::ExifTool::SplitFileName($file);
                    $endDir{$d} = 1;
                    undef $endDir;
                }
            }
        }
        $et->Options( CharsetFileName => $enc ) if $utf8FileName{$file};
        last                                    if $end;
    }
}

sub ScanDir($$;$) {
    local $_;
    my ( $et, $dir, $list ) = @_;
    my ( @fileList, $done, $file, $utf8Name, $winSurrogate, $endThisDir );
    my $enc = $et->Options('CharsetFileName');
    if ($enc) {
        unless ( $enc eq 'UTF8' ) {
            $dir = $et->Decode( $dir, $enc, undef, 'UTF8' );
            $et->Options( CharsetFileName => 'UTF8' );
        }
        $utf8Name = 1;
    }
    return if $ignore{$dir};
    if ( $^O eq 'MSWin32' and not HasWildcards($dir) ) {
        undef $evalWarning;
        local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
        if ( CheckUTF8( $dir, $enc ) >= 0 ) {
            if ( eval { require Win32::FindFile } ) {
                eval {
                    @fileList = Win32::FindFile::ReadDir($dir);
                    $_        = $_->cFileName foreach @fileList;
                };
                $@ and $evalWarning = $@;
                if ($evalWarning) {
                    chomp $evalWarning;
                    $evalWarning =~ s/ at .*//s;
                    Warning( $et, "[Win32::FindFile] $evalWarning - $dir" );
                    $winSurrogate = 1 if $evalWarning =~ /surrogate/;
                }
                else {
                    $et->Options( CharsetFileName => 'UTF8' );
                    $utf8Name = 1;
                    $done     = 1;
                }
            }
            else {
                $done = 0;
            }
        }
    }
    unless ($done) {
        unless ( opendir( DIR_HANDLE, $dir ) ) {
            Warn("Error opening directory $dir\n");
            return;
        }
        @fileList = readdir(DIR_HANDLE);
        closedir(DIR_HANDLE);
        if ( defined $done ) {
            foreach $file ( $dir, @fileList ) {
                next unless $file =~ /[\?\x80-\xff]/;
                WarnOnce(
"Install Win32::FindFile to support Windows Unicode file names in directories\n"
                );
                last;
            }
        }
    }
    $dir =~ /\/$/ or $dir .= '/';
    foreach $file (@fileList) {
        next if $file eq '.' or $file eq '..';
        my $path = "$dir$file";
        if ( $et->IsDirectory($path) ) {
            next unless $recurse;
            next if $file =~ /^\./ and $recurse == 1;
            next if $ignore{$file} or ( $ignore{SYMLINKS} and -l $path );
            ScanDir( $et, $path, $list );
            last if $end;
            next;
        }
        next if $endThisDir;
        next if $ignoreHidden and $file =~ /^\./;

        my $accepted;
        if ($filterFlag) {
            $accepted = AcceptFile($file) or next;
            $accepted &= 0x01;
        }
        unless ($accepted) {
            if ($scanWritable) {
                if ( $scanWritable eq '1' ) {
                    next unless CanWrite($file);
                }
                else {
                    my $type = GetFileType($file);
                    next unless defined $type and $type eq $scanWritable;
                }
            }
            elsif ( not GetFileType($file) ) {
                next unless $doUnzip;
                next unless $file =~ /\.(gz|bz2)$/i;
            }
        }
        if (    $winSurrogate
            and $isWriting
            and ( not $overwriteOrig or $overwriteOrig != 2 )
            and not $doSetFileName
            and $file =~ /~/ )
        {
            Warn("Not writing $path\n");
            WarnOnce(
"Use -overwrite_original_in_place to write files with Unicode surrogate characters\n"
            );
            EFile($file);
            ++$countBad;
            next;
        }
        $utf8FileName{$path} = 1 if $utf8Name;
        if ($list) {
            push( @$list, $path );
        }
        else {
            GetImageInfo( $et, $path );
            Image::ExifTool::Purge($purge) if $purge;
            if ($end) {
                Warn("End called - $file\n");
                last;
            }
            if ($endDir) {
                $path =~ s(/$)();
                Warn("EndDir called - $path\n");
                $endDir{$path} = 1;
                $endThisDir = 1;
                undef $endDir;
            }
        }
    }
    ++$countDir;
    $et->Options( CharsetFileName => $enc );
}

sub FindFileWindows($$) {
    my ( $et, $wildfile ) = @_;

    my $enc = $et->Options('CharsetFileName');
    $wildfile = $et->Decode( $wildfile, $enc, undef, 'UTF8' )
      if $enc and $enc ne 'UTF8';
    CleanFilename($wildfile);
    my ( $dir, $wildname ) =
      ( $wildfile =~ m{(.*[:/])(.*)} ) ? ( $1, $2 ) : ( '', $wildfile );
    if ( HasWildcards($dir) ) {
        Warn "Wildcards don't work in the directory specification\n";
        return ();
    }
    CheckUTF8( $wildfile, $enc ) >= 0 or return ();
    undef $evalWarning;
    local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
    my @files;
    eval {
        my @names = Win32::FindFile::FindFile($wildfile) or return;
        @names = sort { uc($a) cmp uc($b) } @names;
        my ( $rname, $nm );
        ( $rname = quotemeta $wildname ) =~ s/\\\?/./g;
        $rname =~ s/\\\*/.*/g;
        foreach $nm (@names) {
            $nm = $nm->cFileName;
            next unless $nm =~ /^$rname$/i;
            next if $nm eq '.' or $nm eq '..';
            my $file = "$dir$nm";
            push @files, $file;
            $utf8FileName{$file} = 1;
        }
    };
    $@ and $evalWarning = $@;
    if ($evalWarning) {
        chomp $evalWarning;
        $evalWarning =~ s/ at .*//s;
        Warn "Error: [Win32::FindFile] $evalWarning - $wildfile\n";
        undef @files;
        EFile($wildfile);
        ++$countBad;
    }
    return @files;
}

sub FileNotFound($) {
    my $file = shift;
    if ( $file =~ /^(DIR|FILE)$/ ) {
        my $type = { DIR => 'directory', FILE => 'file' }->{$file};
        Warn
qq{You were meant to enter any valid $type name, not "$file" literally.\n};
    }
}

sub PreserveTime() {
    local $_;
    $mt->SetFileTime( $_, @{ $preserveTime{$_} } ) foreach keys %preserveTime;
    undef %preserveTime;
}

sub AbsPath($) {
    my $file = shift;
    my $path;
    if ( defined $file ) {
        return undef if $file eq '*';
        if ( $^O eq 'MSWin32' and $mt->Options('WindowsLongPath') ) {
            $path = $mt->WindowsLongPath($file);
        }
        elsif ( eval { require Cwd } ) {
            local $SIG{'__WARN__'} = sub { };
            $path = eval { Cwd::abs_path($file) };
        }
        CleanFilename($path) if defined $path;
    }
    return $path;
}

sub MyConvertFileName($$) {
    my ( $et, $file ) = @_;
    my $enc = $et->Options('CharsetFileName');
    $et->Options( CharsetFileName => 'UTF8' ) if $utf8FileName{$file};
    my $convFile = $et->ConvertFileName($file);
    $et->Options( CharsetFileName => $enc ) if $utf8FileName{$file};
    return $convFile;
}

sub AddPrintFormat($) {
    my $expr = shift;
    my $type;
    if ( $expr =~ /^#/ ) {
        $expr =~ s/^#\[(HEAD|SECT|IF|BODY|ENDS|TAIL)\]// or return;
        $type = $1;
    }
    else {
        $type = 'BODY';
    }
    $printFmt{$type} or $printFmt{$type} = [];
    push @{ $printFmt{$type} }, $expr;
    push @requestTags, $expr =~ /\$\{?((?:[-_0-9A-Z]+:)*[-_0-9A-Z?*]+)/ig;
    $printFmt{SetTags} = 1 if $expr =~ /\bSetTags\b/;
}

sub SuggestedExtension($$$) {
    my ( $et, $valPt, $tag ) = @_;
    my $ext;
    if ( not $binaryOutput ) {
        $ext = 'txt';
    }
    elsif ( $$valPt =~ /^\xff\xd8\xff/ ) {
        $ext = 'jpg';
    }
    elsif ( $$valPt =~
        /^(\0\0\0\x0cjP(  |\x1a\x1a)\x0d\x0a\x87\x0a|\xff\x4f\xff\x51\0)/ )
    {
        $ext = 'jp2';
    }
    elsif ( $$valPt =~ /^(\x89P|\x8aM|\x8bJ)NG\r\n\x1a\n/ ) {
        $ext = 'png';
    }
    elsif ( $$valPt =~ /^GIF8[79]a/ ) {
        $ext = 'gif';
    }
    elsif ( $$valPt =~ /^<\?xpacket/ or $tag eq 'XMP' ) {
        $ext = 'xmp';
    }
    elsif ( $$valPt =~ /^<\?xml/ or $tag eq 'XML' ) {
        $ext = 'xml';
    }
    elsif ( $$valPt =~ /^RIFF....WAVE/s ) {
        $ext = 'wav';
    }
    elsif ( $tag eq 'OriginalRawImage'
        and defined( $ext = $et->GetValue('OriginalRawFileName') ) )
    {
        $ext =~ s/^.*\.//s;
        $ext = $ext ? lc($ext) : 'raw';
    }
    elsif ( $tag eq 'EXIF' ) {
        $ext = 'exif';
    }
    elsif ( $tag eq 'ICC_Profile' ) {
        $ext = 'icc';
    }
    elsif ( $$valPt =~ /^(MM\0\x2a|II\x2a\0)/ ) {
        $ext = 'tiff';
    }
    elsif ( $$valPt =~ /^.{4}ftyp(3gp|mp4|f4v|qt  )/s ) {
        my %movType = ( 'qt  ' => 'mov' );
        $ext = $movType{$1} || $1;
    }
    elsif ( $$valPt =~ /^<(!DOCTYPE )?html/i ) {
        $ext = 'html';
    }
    elsif ( $$valPt =~ /^[\n\r]*\{[\n\r]*\\rtf/ ) {
        $ext = 'rtf';
    }
    elsif ( $$valPt !~ /^.{0,4096}\0/s ) {
        $ext = 'txt';
    }
    elsif ( $$valPt =~ /^BM.{15}\0/s ) {
        $ext = 'bmp';
    }
    elsif ( $$valPt =~ /^CANON OPTIONAL DATA\0/ ) {
        $ext = 'vrd';
    }
    elsif ( $$valPt =~ /^IIII\x04\0\x04\0/ ) {
        $ext = 'dr4';
    }
    elsif ( $$valPt =~ /^(.{10}|.{522})(\x11\x01|\x00\x11)/s ) {
        $ext = 'pict';
    }
    elsif ( $$valPt =~ /^\xff\x0a|\0\0\0\x0cJXL \x0d\x0a......ftypjxl/s ) {
        $ext = 'jxl';
    }
    elsif ( $$valPt =~ /^.{4}jumb\0.{3}jumdc2pa/s ) {
        $ext = 'c2pa';
    }
    elsif ( $tag eq 'JUMBF' ) {
        $ext = 'jumbf';
    }
    else {
        $ext = 'dat';
    }
    return $ext;
}

sub LoadPrintFormat($;$) {
    my ( $arg, $noNL ) = @_;
    if ( not defined $arg ) {
        Error "Must specify file or expression for -p option\n";
    }
    elsif ( $arg !~ /\n/ and -f $arg and $mt->Open( \*FMT_FILE, $arg ) ) {
        foreach (<FMT_FILE>) {
            AddPrintFormat($_);
        }
        close(FMT_FILE);
    }
    else {
        $arg .= "\n" unless $noNL;
        AddPrintFormat($arg);
    }
}

sub FilenameSPrintf($;$@) {
    my ( $fmt, $file, @extra ) = @_;
    local $_;
    return $fmt  unless $fmt =~ /%[-+]?\d*[.:]?\d*[lu]?[dDfFeEtgso]/;
    return undef unless defined $file;
    CleanFilename($file);

    my %part;
    @part{qw(d f E)} = ( $file =~ /^(.*?)([^\/]*?)(\.[^.\/]*)?$/ );
    defined $part{f}
      or Warn("Error: Bad pattern match for file $file\n"), return undef;
    if ( $part{E} ) {
        $part{e} = substr( $part{E}, 1 );
    }
    else {
        @part{qw(e E)} = ( '', '' );
    }
    $part{F} = $part{f} . $part{E};
    ( $part{D} = $part{d} ) =~ s{/+$}{};
    @part{qw(t g s o)} = @extra;
    $part{o} =~ s(^.*[/\\])()s if $part{o};
    my ( $filename, $pos ) = ( '', 0 );
    while ( $fmt =~ /(%([-+]?)(\d*)([.:]?)(\d*)([lu]?)([dDfFeEtgso]))/g ) {
        $filename .= substr( $fmt, $pos, pos($fmt) - $pos - length($1) );
        $pos = pos($fmt);
        my ( $sign, $wid, $dot, $skip, $mod, $code ) =
          ( $2, $3, $4, $5 || 0, $6, $7 );
        my ( @path, $part, $len, $groups );
        if ( lc $code eq 'd' and $dot and $dot eq ':' ) {
            @path = split '/', $part{$code};
            $len  = scalar @path;
        }
        else {
            if ( $code eq 'g' ) {
                $groups = $part{g} || [] unless defined $groups;
                $fmt =~ /\G(\d?)/g;
                $part{g} = $$groups[ $1 || 0 ];
                $pos = pos($fmt);
            }
            $part{$code} = '' unless defined $part{$code};
            $len = length $part{$code};
        }
        next unless $skip < $len;
        $wid  = $len - $skip        if $wid eq '' or $wid + $skip > $len;
        $skip = $len - $wid - $skip if $sign eq '-';
        if (@path) {
            $part = join( '/', @path[ $skip .. ( $skip + $wid - 1 ) ] );
            $part .= '/' unless $code eq 'D';
        }
        else {
            $part = substr( $part{$code}, $skip, $wid );
        }
        $part = ( $mod eq 'u' ) ? uc($part) : lc($part) if $mod;
        $filename .= $part;
    }
    $filename .= substr( $fmt, $pos );

    $filename =~ s{(?!^)//}{/}g;
    return $filename;
}

sub Num2Alpha($) {
    my $num   = shift;
    my $alpha = chr( 97 + ( $num % 26 ) );
    while ( $num >= 26 ) {
        $num   = int( $num / 26 ) - 1;
        $alpha = chr( 97 + ( $num % 26 ) ) . $alpha;
    }
    return $alpha;
}

sub NextUnusedFilename($;$) {
    my ( $fmt, $okfile ) = @_;
    return $fmt unless $fmt =~ /%[-+]?\d*[.:]?\d*[lun]?[cC]/;
    my %sep = ( '-' => '-', '+' => '_' );
    my ( $copy, $alpha ) = ( 0, 'a' );
    my $lastFile;
    for ( ; ; ) {
        my ( $filename, $pos ) = ( '', 0 );
        while ( $fmt =~ /(%([-+]?)(\d*)([.:]?)(\d*)([lun]?)([cC]))/g ) {
            $filename .= substr( $fmt, $pos, pos($fmt) - $pos - length($1) );
            $pos = pos($fmt);
            my ( $sign, $wid, $dec, $wid2, $mod, $tok ) =
              ( $2, $3 || 0, $4, $5 || 0, $6, $7 );
            my $seq;
            if ( $tok eq 'C' ) {
                $sign eq '-' ? ++$seqFileDir : ++$seqFileNum
                  if $copy and $dec eq ':';
                $seq = $wid + ( $sign eq '-' ? $seqFileDir : $seqFileNum ) - 1;
                $wid = $wid2;
            }
            else {
                next unless $dec or $copy;
                $wid = $wid2 if $wid < $wid2;
                $filename .= $sep{$sign} if $sign;
            }
            if ( $mod and $mod ne 'n' ) {
                my $a = $tok eq 'C' ? Num2Alpha($seq) : $alpha;
                my $str =
                  ( $wid and $wid > length $a )
                  ? 'a' x ( $wid - length($a) )
                  : '';
                $str .= $a;
                $str = uc $str if $mod eq 'u';
                $filename .= $str;
            }
            else {
                my $c   = $tok eq 'C' ? $seq : $copy;
                my $num = $c + ( $mod ? 1 : 0 );
                $filename .= $wid ? sprintf( "%.${wid}d", $num ) : $num;
            }
        }
        $filename .= substr( $fmt, $pos );

        return $filename
          unless ( $mt->Exists( $filename, 1 )
            and not defined $usedFileName{$filename} )
          or $usedFileName{$filename};
        if ( defined $okfile ) {
            return $filename if $filename eq $okfile;
            my ( $fn, $ok ) = ( AbsPath($filename), AbsPath($okfile) );
            return $okfile if defined $fn and defined $ok and $fn eq $ok;
        }
        return $filename if defined $lastFile and $lastFile eq $filename;
        $lastFile = $filename;
        ++$copy;
        ++$alpha;
    }
}

sub CreateDirectory($) {
    my $file = shift;
    my $err  = $mt->CreateDirectory($file);
    if ( defined $err ) {
        $err and Error("$err\n"), return 0;
        if ($verbose) {
            my $dir;
            ( $dir = $file ) =~ s(/[^/]*$)();
            print $vout "Created directory $dir\n";
        }
        ++$countNewDir;
        return 1;
    }
    return 0;
}

sub OpenOutputFile($;@) {
    my ( $file, @args ) = @_;
    my ( $fp, $outfile, $append );
    if ($textOut) {
        $outfile = $file;
        CleanFilename($outfile);
        if ( $textOut =~ /%[-+]?\d*[.:]?\d*[lun]?[dDfFeEtgsocC]/
            or defined $tagOut )
        {
            $outfile = FilenameSPrintf( $textOut, $file, @args );
            return () unless defined $outfile;
            $outfile = NextUnusedFilename($outfile);
            CreateDirectory($outfile);
        }
        else {
            $outfile =~ s/\.[^.\/]*$//;
            $outfile .= $textOut;
        }
        my $mode = '>';
        if ( $mt->Exists( $outfile, 1 ) ) {
            unless ($textOverwrite) {
                Warn "Output file $outfile already exists for $file\n";
                return ();
            }
            if ( $textOverwrite == 2
                or ( $textOverwrite == 3 and $created{$outfile} ) )
            {
                $mode   = '>>';
                $append = 1;
            }
        }
        unless ( $mt->Open( \*OUTFILE, $outfile, $mode ) ) {
            my $what = $mode eq '>' ? 'creating' : 'appending to';
            Error("Error $what $outfile\n");
            return ();
        }
        binmode(OUTFILE) if $binaryOutput;
        $fp = \*OUTFILE;
    }
    else {
        $fp = \*STDOUT;
    }
    return ( $fp, $outfile, $append );
}

sub AcceptFile($) {
    my $file = shift;
    my $ext  = ( $file =~ /^.*\.(.+)$/s ) ? uc($1) : '';
    return $filterExt{$ext} if defined $filterExt{$ext};
    return $filterExt{'*'}  if defined $filterExt{'*'};
    return 0                if $filterFlag & 0x02;
    return 2;
}

sub SlurpFile($$) {
    my ( $file, $buffPt ) = @_;
    $mt->Open( \*INFILE, $file )
      or Warn("Error opening file $file\n"), return 0;
    binmode(INFILE);
    undef $$buffPt;
    my $bsize = 1024 * 1024;
    my $num   = read( INFILE, $$buffPt, $bsize );
    unless ( defined $num ) {
        close(INFILE);
        Warn("Error reading $file\n");
        return 0;
    }
    my $bmax = 64 * $bsize;
    while ( $num == $bsize ) {
        $bsize *= 2 if $bsize < $bmax;
        my $buff;
        $num = read( INFILE, $buff, $bsize );
        last unless $num;
        $$buffPt .= $buff;
    }
    close(INFILE);
    return 1;
}

sub FilterArgfileLine($) {
    my $arg = shift;
    if ( $arg =~ /^#/ ) {
        return undef unless $arg =~ s/^#\[CSTR\]//;
        $arg =~ s/[\x0d\x0a]+$//s;

        $arg =~ s{\\(.)|(["\$\@]|\\$)}{'\\'.($2 || $1)}sge;
        my %esc = (
            a    => "\a",
            b    => "\b",
            f    => "\f",
            n    => "\n",
            r    => "\r",
            t    => "\t",
            '"'  => '"',
            '\\' => '\\'
        );
        $arg =~ s/\\(.)/$esc{$1}||'\\'.$1/egs;
    }
    else {
        $arg =~ s/^\s+//;
        $arg =~ s/[\x0d\x0a]+$//s;

        $arg =~ s/^(-[-_0-9A-Z:]+#?)\s*([-+<]?=) ?/$1$2/i;
        return undef if $arg eq '';
    }
    return $arg;
}

sub ReadStayOpen($) {
    my $args = shift;
    my ( @newArgs, $processArgs, $result, $optArgs );
    my $lastOpt  = '';
    my $unparsed = length $stayOpenBuff;
    for ( ; ; ) {
        if ($unparsed) {
            $result = $unparsed;
            undef $unparsed;
        }
        else {
            $result =
              sysread( STAYOPEN, $stayOpenBuff, 65536, length($stayOpenBuff) );
        }
        if ($result) {
            my $pos = 0;
            while ( $stayOpenBuff =~ /\n/g ) {
                my $len = pos($stayOpenBuff) - $pos;
                my $arg = substr( $stayOpenBuff, $pos, $len );
                $pos += $len;
                $arg = FilterArgfileLine($arg);
                next unless defined $arg;
                push @newArgs, $arg;
                if ($optArgs) {
                    undef $optArgs;
                    next unless $lastOpt eq '-stay_open' or $lastOpt eq '-@';
                }
                else {
                    $lastOpt = lc $arg;
                    $optArgs = $optArgs{$arg};
                    unless ( defined $optArgs ) {
                        $optArgs = $optArgs{$lastOpt};
                        $optArgs = $optArgs{"$1#$2"}
                          if not defined $optArgs
                          and $lastOpt =~ /^(.*?)\d+(!?)$/;
                    }
                    next unless $lastOpt =~ /^-execute\d*$/;
                }
                $processArgs = 1;
                last;
            }
            next unless $pos;

            $stayOpenBuff = substr( $stayOpenBuff, $pos );
            if ($processArgs) {
                unshift @$args, @newArgs;
                last;
            }
        }
        elsif ( $result == 0 ) {
            select( undef, undef, undef, 0.01 );
        }
        else {
            Warn "Error reading from ARGFILE\n";
            close STAYOPEN;
            $stayOpen = 0;
            last;
        }
    }
}

sub EFile($$) {
    my $entry = shift;
    my $efile = $efile[ shift || 0 ];
    if ( defined $efile and length $entry and $entry ne '-' ) {
        my $err;
        CreateDirectory($efile);
        if ( $mt->Open( \*EFILE_FILE, $efile, '>>' ) ) {
            print EFILE_FILE $entry, "\n"
              or Warn("Error writing to $efile\n"), $err = 1;
            close EFILE_FILE;
        }
        else {
            Warn("Error opening '${efile}' for append\n");
            $err = 1;
        }
        if ($err) {
            defined $_ and $_ eq $efile and undef $_ foreach @efile;
        }
    }
}

sub Progress($$) {
    my ( $file, $msg ) = @_;
    if ( defined $progStr ) {
        print $file $msg, $progStr, "\n";
        undef $progressNext if defined $progressMax;
    }
}

sub PrintTagList($@) {
    my $msg = shift;
    print $msg, ":\n" unless $quiet;
    my $tag;
    if ( ( $outFormat < 0 or $verbose ) and $msg =~ /file extensions$/ and @_ )
    {
        foreach $tag (@_) {
            printf( "  %-11s %s\n", $tag, GetFileType( $tag, 1 ) );
        }
        return;
    }
    my ( $len, $pad ) = ( 0, $quiet ? '' : '  ' );
    foreach $tag (@_) {
        my $taglen = length($tag);
        if ( $len + $taglen > 77 ) {
            print "\n";
            ( $len, $pad ) = ( 0, $quiet ? '' : '  ' );
        }
        print $pad, $tag;
        $len += $taglen + 1;
        $pad = ' ';
    }
    @_ or print $pad, '[empty list]';
    print "\n";
}

sub PrintErrors($$$) {
    my ( $et, $info, $file ) = @_;
    my ( $tag, $key );
    foreach $tag (qw(Warning Error)) {
        next unless $$info{$tag};
        my @keys = ($tag);
        push @keys, sort( grep /^$tag /, keys %$info )
          if $et->Options('Duplicates');
        foreach $key (@keys) {
            Warn "$tag: $info->{$key} - $file\n";
        }
    }
    return $$info{Error};
}

__END__


#------------------------------------------------------------------------------
# end
