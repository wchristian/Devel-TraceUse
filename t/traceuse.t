#!perl

use strict;
use warnings;
use Test::More;
use IPC::Open3;
use File::Spec;

my $tlib  = File::Spec->catdir( 't', 'lib' );
my $tlib2 = File::Spec->catdir( 't', 'lib2' );

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
    [ << 'OUT', '-d:TraceUse', "-Mlib=$tlib2", '-MM8', '-e1' ],
Modules used from -e:
   *.  lib, -e line 0 [main]
Modules used, but not reported:
  M8.pm
OUT
    [ << 'OUT', '-d:TraceUse', "-Mlib=$tlib2", '-MM1', '-MM8', '-e1' ],
Modules used from -e:
   *.  lib, -e line 0 [main]
   *.  M1, -e line 0 [main]
   *.    M2, M1.pm line 3
   *.      M3, M2.pm line 3
   *.  M8, -e line 0 [main]
OUT
    [ << 'OUT', '-d:TraceUse', "-Mlib=$tlib2", '-MM7', '-MM8', '-e1' ],
Modules used from -e:
   *.  lib, -e line 0 [main]
   *.  M7, -e line 0 [main]
   *.  M8, -e line 0 [main]
OUT
    [ << 'OUT', qw(-d:TraceUse -e), 'eval { require M10 }' ],
Modules used from -e:
   1.  M10, -e line 1 [main] (FAILED)
OUT
    [   << 'OUT', qw(-d:TraceUse -e), "eval { require M10 };\npackage M11;\neval { require M10 }" ],
Modules used from -e:
   1.  M10, -e line 1 [main] (FAILED)
   2.  M10, -e line 3 [M11] (FAILED)
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
    [ << 'OUT', qw(-d:TraceUse -MM9 -e1) ],
Modules used from -e:
   1.  M9, -e line 0 [main]
   2.    M6, M9.pm line 3 (eval 1)
OUT
    [ << 'OUT', qw(-MDevel::TraceUse -MM9 -e1) ],
Modules used from -e:
   1.  M9, -e line 0 [main]
   2.  M6, (eval 1) [M9]
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

    # special case of use lib
    @errput = clean_lib(@errput) if grep / lib,/, @errput;

    # compare the results
    ( my $mesg = "Trace for: perl @cmd" ) =~ s/\n/\\n/g;
    is_deeply( \@errput, [ split /\n/, $errput ], $mesg )
        or print map {"$_\n"} @errput;
}

# ignore modules loaded by lib, as they may have changed over time
sub clean_lib {
    my @lines = @_;
    my $lib   = 0;
    my $tab;
    for (@lines) {
        s/^(\s*)(\d+)\./$1*./;
        if (/\.( +)lib,/) {
            $lib = 1;
            $tab = $1 . '  ';
            next;
        }
        if ($lib) {
            if   (/\.$tab/) { $_   = 'deleted' }
            else            { $lib = 0 }
        }
    }
    return grep { $_ ne 'deleted' } @lines;
}

