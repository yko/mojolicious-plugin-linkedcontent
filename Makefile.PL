use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Mojolicious::Plugin::LinkedContent',
    AUTHOR              => 'Yaroslav Korshak <yaroslav@korshak.name>',
    VERSION_FROM        => 'lib/Mojolicious/Plugin/LinkedContent.pm',
    ABSTRACT_FROM       => 'lib/Mojolicious/Plugin/LinkedContent.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'mojolicious-plugin-linkedcontent-*' },
);
