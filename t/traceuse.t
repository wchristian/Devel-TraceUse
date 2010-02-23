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
    [ << 'OUT', qw(-d:TraceUse -MM1 -e1) ],
Modules used from -e:
   1.  M1, -e line 0 [main]
   2.    M2, M1.pm line 3
   3.      M3, M2.pm line 3
OUT
    [ << 'OUT', qw(-d:TraceUse -MM4 -e1) ],
Modules used from -e:
   1.  M4, -e line 0 [main]
   2.    M5, M4.pm line 3
   3.      M6, M5.pm line 9 [M5::in]
OUT
    [ << 'OUT', qw(-d:TraceUse -MM1 -e), 'require M4' ],
Modules used from -e:
   1.  M1, -e line 0 [main]
   2.    M2, M1.pm line 3
   3.      M3, M2.pm line 3
   4.  M4, -e line 1 [main]
   5.    M5, M4.pm line 3
   6.      M6, M5.pm line 9 [M5::in]
OUT
    [ << 'OUT', qw(-d:TraceUse -e), 'require M4; use M1' ],
Modules used from -e:
   1.  M1, -e line 1 [main]
   2.    M2, M1.pm line 3
   3.      M3, M2.pm line 3
   4.  M4, -e line 1 [main]
   5.    M5, M4.pm line 3
   6.      M6, M5.pm line 9 [M5::in]
OUT
    [ << 'OUT', qw(-d:TraceUse -MM4 -MM1 -e M5->load) ],
Modules used from -e:
   1.  M4, -e line 0 [main]
   2.    M5, M4.pm line 3
   3.      M6, M5.pm line 9 [M5::in]
   7.      M7, M5.pm line 4
   4.  M1, -e line 0 [main]
   5.    M2, M1.pm line 3
   6.      M3, M2.pm line 3
OUT
    [ << 'OUT', qw(-d:TraceUse -e), 'eval { use M1 }' ],
Modules used from -e:
   1.  M1, -e line 1 [main]
   2.    M2, M1.pm line 3
   3.      M3, M2.pm line 3
OUT
);

# -MDevel::TraceUse usually produces the same output as -d:TraceUse
for ( 0 .. $#tests ) {
    push( @tests, [ @{ $tests[$_] } ] );
    $tests[-1][1] = '-MDevel::TraceUse';
}

# but there are some exceptions
push @tests, (
    [ << 'OUT', qw(-d:TraceUse -e), 'eval "use M1"' ],
Modules used from -e:
   1.  M1, -e line 1 (eval 1) [main]
   2.    M2, M1.pm line 3
   3.      M3, M2.pm line 3
OUT
    [ << 'OUT', qw(-MDevel::TraceUse -e), 'eval "use M1"' ],
Modules used from -e:
   1.  M1, (eval 1) [main]
   2.    M2, M1.pm line 3
   3.      M3, M2.pm line 3
OUT
);

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
    ) or print map { "$_\n" } @errput;
}

