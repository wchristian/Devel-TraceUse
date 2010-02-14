#!perl

use strict;
use warnings;
use Test::More;
use IPC::Open3;
use File::Spec;

my $tlib = File::Spec->catdir( 't', 'lib' );

# all command lines prefixed with $^X -I"t/lib"
my @tests = (
    [ << 'OUT', qw(-d:TraceUse -MParent -e1) ],
Modules used from -e:
   1.  Parent, -e line 0 [main]
   2.    Child, Parent.pm line 3
   3.      Sibling, Child.pm line 3
OUT
    [ << 'OUT', qw(-d:TraceUse -MChild -e1) ],
Modules used from -e:
   1.  Child, -e line 0 [main]
   2.    Sibling, Child.pm line 3
   3.      Parent, Sibling.pm line 4
OUT
    [ << 'OUT', qw(-d:TraceUse -MSibling -e1) ],
Modules used from -e:
   1.  Sibling, -e line 0 [main]
   2.    Child, Sibling.pm line 3
   3.      Parent, Child.pm line 4
OUT
);

# in most cases, -d:TraceUse has the same effect as -MDevel::TraceUse
for ( 0 .. 2 ) {
    push( @tests, [ @{ $tests[$_] } ] );
    $tests[-1][1] = '-MDevel::TraceUse';
}

plan tests => scalar @tests;

for my $test (@tests) {
    my ( $errput, @cmd ) = @$test;

    # run the test subcommand
    local ( *IN, *OUT, *ERR );
    my $pid = open3( \*IN, \*OUT, \*ERR, $^X, '-Iblib/lib', "-I$tlib", @cmd );
    my @errput = map { chomp; $_ } <ERR>;
    waitpid( $pid, 0 );

    # compare the results
    is_deeply(
        \@errput,
        [ split /\n/, $errput ],
        "Trace for: perl @cmd"
    ) or print $errput;
}

