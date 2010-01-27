use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Mojolicious::Plugin::LinkedContent',
    license             => 'perl',
    dist_author         => 'Yaroslav Korshak <yaroslav@korshak.name>',
    dist_version_from   => 'lib/Mojolicious/Plugin/LinkedContent.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'mojolicious-plugin-linkedcontent-*' ],
);

$builder->create_build_script();
