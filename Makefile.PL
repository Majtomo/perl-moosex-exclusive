use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'MooseX::Trait::ExclusiveAttributes',
    AUTHOR           => 'Jean-Antoine RINALDY <m4jtom@gmail.com>',
    VERSION_FROM     => 'lib/MooseX/Trait/ExclusiveAttributes.pm',
    ABSTRACT         => 'A trait for mutually exclusive attributes',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => '5.036',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'Test::More' => '0',
        'Test::Exception' => '0',
    },
    PREREQ_PM => {
        'Moose' => '2.0',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'MooseX-Trait-ExclusiveAttributes-*' },
);