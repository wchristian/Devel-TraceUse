use strict;
use warnings;
use Test::More;
use Devel::TraceUse ();    # disable reporting

my @versions = (
    qw(
        5.1        5.001
        5.01       5.001
        5.005      5.005
        5.5.30     5.00503
        5.005_03   5.00503
        5.6        5.006
        5.06       5.006
        5.006      5.006
        5.6.1      5.006001
        5.6.01     5.006001
        5.6.001    5.006001
        5.06.01    5.006001
        5.006.001  5.006001
        5.010001   5.010001
        5.10       5.01
        5.60       5.06
        5.600      5.6
        )
);

plan tests => @versions / 2;

while (@versions) {
    my ( $version, $expected ) = splice @versions, 0, 2;
    my $got = Devel::TraceUse::numify($version);
    is( $got, $expected, "$version => $expected" );
}

