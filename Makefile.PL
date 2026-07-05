use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'AsyncWebAPI',
    VERSION_FROM    => 'AsyncWebAPI.pm',
    PM              => { 'AsyncWebAPI.pm' => '$(INST_LIB)/AsyncWebAPI.pm' },
    INC             => '-I../../stubs',
);
