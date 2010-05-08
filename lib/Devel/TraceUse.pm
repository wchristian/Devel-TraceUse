package # hide package name from indexer
  DB;

# allow -d:TraceUse loading with this little C++-style no-op
sub DB {}

package Devel::TraceUse;

our $VERSION = '2.01';

BEGIN
{
	unshift @INC, \&trace_use unless grep { "$_" eq \&trace_use . '' } @INC;
}

# initialize the tree of require calls
my $root = (caller)[1];
my %used;
my %loaded;
my %reported;
my $rank = 0;

my @caller_info = qw( package filepath line subroutine hasargs
	wantarray evaltext is_require hints bitmask hinthash );

# Keys used in the data structure:
# - filename: parameter given to use/require
# - module:   module, computed from filename
# - rank:     rank of loading
# - eval:     was this use/require done in an eval?
# - loaded:   list of files loaded from this one
# - filepath: file that was actually loaded from disk (obtained from %INC)
# - caller:   information on the caller (same keys + everything from caller())

sub trace_use
{
	my ( $code, $filename ) = @_;

	# ensure our hook remains first in @INC
	@INC = ( $code, grep { $_ ne $code } @INC )
		if $INC[0] ne $code;

	# $filename may be an actual filename, e.g. with do()
	# try to compute a module name from it
	my $module = $filename;
	$module =~ s{/}{::}g
		if $module =~ s/\.pm$//;

	# info about the module being loaded
	push @{ $used{$filename} }, my $info = {
		filename => $filename,
		module   => $module,
		rank     => ++$rank,
		eval     => '',
	};

	# info about the loading module
	my $caller = $info->{caller} = {};
	@{$caller}{@caller_info} = caller(0);

	# try to compute a "filename" (as received by require)
	$caller->{filestring} = $caller->{filename} = $caller->{filepath};

	# some values seen in the wild:
	# - "(eval $num)[$path:$line]" (debugger)
	# - "$filename (autosplit into $path)" (AutoLoader)
	if ( $caller->{filename} =~ /^(\(eval \d+\))(?:\[(.*):(\d+)\])?$/ ) {
		$info->{eval}       = $1;
		$caller->{filename} = $caller->{filepath} = $2;
		$caller->{line}     = $3;
	}

	# clean up path
	$caller->{filename}
		=~ s{^(?:@{[ join '|', map quotemeta, reverse sort @INC]})/?}{};

	# try to compute the package associated with the file
	$caller->{filepackage} = $caller->{filename};
	$caller->{filepackage} =~ s/\.(pm|al)\s.*$/.$1/;
	$caller->{filepackage} =~ s{/}{::}g
		if $caller->{filepackage} =~ s/\.pm$//;

	# record who tried to load us
	push @{ $loaded{ $caller->{filepath} } }, $info->{filename};

	# let Perl ultimately find the required file
	return;
}

sub show_trace
{
	my ( $mod, $pos ) = @_;

	if ( ref $mod ) {
		$mod = shift @$mod;
		my $caller = $mod->{caller};
		my $message = sprintf( '%4s.', $mod->{rank} ) . '  ' x $pos;
		$message .= "$mod->{module},";
		$message .= " $caller->{filename}"
			if defined $caller->{filename};
		$message .= " line $caller->{line}"
			if defined $caller->{line};
		$message .= " $mod->{eval}"
			if $mod->{eval};
		$message .= " [$caller->{package}]"
			if $caller->{package} ne $caller->{filepackage};
		$message .= " (FAILED)"
			if !exists $INC{$mod->{filename}};
		warn "$message\n";
		$reported{$mod->{filename}}++;
	}
	else {
		$mod = { loaded => delete $loaded{$mod} };
	}

	show_trace( $used{$_}, $pos + 1 )
		for map { $INC{$_} || $_ } @{ $mod->{loaded} };
}

END
{

	# map "filename" to "filepath" for everything that was loaded
	while ( my ( $filename, $filepath ) = each %INC ) {
		if ( exists $used{$filename} ) {
			$used{$filename}[0]{loaded} = delete $loaded{$filepath} || [];
			$used{$filepath} = delete $used{$filename};
		}
	}

	# output the diagnostic
	warn "Modules used from $root:\n";
	show_trace( $root, 0 );

	# anything left?
	if (%loaded) {
		show_trace($_) for sort keys %loaded;
	}

	# did we miss some modules?
	if (my @missed
		= sort grep { !exists $reported{$_} && $_ ne 'Devel/TraceUse.pm' }
		keys %INC
		)
	{
		warn "Modules used, but not reported:\n" if @missed;
		warn "  $_\n" for @missed;
	}
}

1;
__END__

=head1 NAME

Devel::TraceUse - show the modules your program loads, recursively

=head1 SYNOPSIS

An apparently simple program may load a lot of modules.  That's useful, but
sometimes you may wonder exactly which part of your program loads which module.

C<Devel::TraceUse> can analyze a program to see which part used which module.
I recommend using it from the command line:

  $ B<perl -d:TraceUse your_program.pl>

This will display a tree of the modules ultimately used to run your program.
(It also runs your program with only a little startup cost all the way through
to the end.)

  Modules used from your_program.pl:
     1.  strict, your_program.pl line 1 [main]
     2.  warnings, your_program.pl line 2 [main]
     3.  Getopt::Long, your_program.pl line 3 [main]
     4.    vars, Getopt/Long.pm line 37
     5.      warnings::register, vars.pm line 7
     6.    Exporter, Getopt/Long.pm line 43
     9.      Exporter::Heavy, Exporter.pm line 18
     7.    constant, Getopt/Long.pm line 226
     8.    overload, Getopt/Long.pm line 1487 [Getopt::Long::CallBack]

The load order is listed on the first column. The calling package is
shown between square brackets if different from the package that can
be inferred from the file name. Extra information is also provided
if the module was loaded from within and C<eval>.

C<Devel::TraceUse> will also report modules that failed to be loaded,
under the modules that tried to load them.

In the very rare case when C<Devel::TraceUse> is not able to attach
a loaded module to the tree, it will be reported at the end.

Even though using C<-MDevel::TraceUse> is possible, it is preferable to
use C<-d:TraceUse>, as the debugger will provide more accurate information
in the case of C<eval>.

=head1 AUTHORS

chromatic, C<< <chromatic at wgz.org> >>

Philippe Bruhat, C<< <book at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-devel-traceuse at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devel-TraceUse>.  We can both track it there.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Devel::TraceUse

You can also look for information at:

=over 4

=item * I<Perl Hacks>, hack #74

O'Reilly Media, 2006.

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Devel-TraceUse>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Devel-TraceUse>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Devel-TraceUse>

=item * Search CPAN

L<http://search.cpan.org/dist/Devel-TraceUse>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2006 chromatic, most rights reserved.

Copyright 2010 Philippe Bruhat (BooK), for the rewrite.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
