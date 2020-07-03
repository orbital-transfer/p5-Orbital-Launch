use strict;
use warnings;
package Oberth::Launch::System::MSWin32::EUMMnosearch;
# ABSTRACT: Hack ExtUtils::MakeMaker library searching on MSWin32

package main;
# only run when we call the Makefile.PL script
if( $0 eq "Makefile.PL" || $0 eq "./Makefile.PL"  ) {
	require ExtUtils::MakeMaker;
	require ExtUtils::Liblist::Kid;

	open(my $f, '<', $0) or die "OPENING $0 $!\n";
	my $makefile_contents = do { local($/); <$f> };
	close($f);

	my $eumm_targ = "main";
	if( $makefile_contents =~ /^use XS::Install/m ) {
		$eumm_targ = 'XS::Install';
	}

	my $i = ExtUtils::MakeMaker->can("import");
	no warnings "redefine";
	no warnings "once";
	*ExtUtils::MakeMaker::import = sub {
		&$i;
		#my $targ = caller;
		my $targ = $eumm_targ;
		#my $wm = $targ->can("WriteMakefile");
		my $wm = ExtUtils::MakeMaker->can("WriteMakefile");
		print "$targ\n";
		no strict "refs"; ## no critic: 'RequireUseStrict'
		*{"${targ}::WriteMakefile"} = sub {
			my %args = @_;
			# Only apply :nosearch after lib linker directory
			# for entire mingw64 system. This way XS modules
			# that depend on other XS modules can compile
			# statically using .a files.
			#
			# The pattern needs to be case-insensitive because
			# Windows is case-insensitive.
			chomp(my $lib_path = `cygpath -m /mingw64/lib`);
			if( $args{LIBS} && ref $args{LIBS} eq 'ARRAY' ) {
				$args{LIBS} = join " ", @{ $args{LIBS} };
			}
			$args{LIBS} = '' unless $args{LIBS};
			$args{LIBS} =~ s,^(.*?)(\Q-L$lib_path\E\s),$1 :nosearch $2,i;

			# Special case for expat (XML::Parser::Expat) because
			# it does not use either of
			#
			#   - -L<libpath>
			#   - pkg-config --libs expat
			$args{LIBS} =~ s,(\Q-lexpat\E),:nosearch $1,;

			# Special case for XS::libpanda
			if( $args{NAME} eq 'XS::libpanda' ) {
				$args{LIBS} =~ s,^(.*)$,:nosearch $1 :search,;
				$args{LIBS} =~ s/-lexecinfo//g;
			}
			print "LIBS: $args{LIBS}\n";
			$wm->(%args);
		};
	};

	*ExtUtils::Liblist::Kid::_win32_search_file = sub {
		my ( $thislib, $libext, $paths, $verbose, $GC ) = @_;

		my @file_list = ExtUtils::Liblist::Kid::_win32_build_file_list( $thislib, $GC, $libext );

		for my $path ( @{$paths} ) {
			for my $lib_file ( @file_list ) {
				my $fullname = $lib_file;
				$fullname = "$path\\$fullname" if $path;
				print $fullname, "\n";
				print `ls $fullname`, "\n";

				return ( $fullname, $path ) if -f $fullname;

				ExtUtils::Liblist::Kid::_debug( "'$thislib' not found as '$fullname'\n", $verbose );
			}
		}

		return;
	};

	my $exit = eval { do $0 };
	warn "Hack failed: (exit: $exit) $@" if $@ || $exit;

	# we can exit now that we are done
	exit 0;
}

1;
