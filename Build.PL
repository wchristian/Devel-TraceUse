#! perl

use Module::Build;

use strict;
use warnings;

my $builder = Module::Build->new(
    module_name         => 'Devel::TraceUse',
    license             => 'perl',
    dist_author         => 'Philippe Bruhat (BooK) <book@cpan.org>',
    dist_version_from   => 'lib/Devel/TraceUse.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Devel-TraceUse-*' ],
	no_index            => {
	       package => [ 'Foo::Bar', ]
	},
    meta_merge => {
        resources => {
            repository => 'http://github.com/book/Devel-TraceUse',
        },
    },
);

$builder->create_build_script();
