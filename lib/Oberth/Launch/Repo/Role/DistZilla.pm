use Modern::Perl;
package Oberth::Launch::Repo::Role::DistZilla;
# ABSTRACT: A role for Dist::Zilla repos

use Mu::Role;

use File::Which;
use Module::Load;
use File::Temp qw(tempdir);
use File::chdir;
use File::HomeDir;
use Path::Tiny;
use Module::Reader;

use Oberth::Manoeuvre::Common::Setup;
use Oberth::Launch::System::Debian::Meson;
use Oberth::Launch::EnvironmentVariables;

lazy environment => method() {
	my $parent = $self->platform->environment;
	my $env = Oberth::Launch::EnvironmentVariables->new(
		parent => $parent
	);

	my @packages = @{ $self->debian_get_packages };
	if( grep { $_ eq 'meson' } @packages ) {
		my $meson = Oberth::Launch::System::Debian::Meson->new(
			runner => $self->runner,
			platform => $self->platform,
		);
		$env->add_environment( $meson->environment );
	}

	$env;
};

lazy test_environment => method() {
	my $env = Oberth::Launch::EnvironmentVariables->new(
		parent => $self->environment
	);

	$env->set_string('AUTHOR_TESTING', 1 );

	# Accessibility <https://github.com/oberth-manoeuvre/oberth-prototype/issues/30>
	$env->set_string('QT_ACCESSIBILITY', 0 );
	$env->set_string('NO_AT_BRIDGE', 1 );

	$env;
};

method _install_perl_deps_cpanm_dir_arg() {
	my $global = $self->config->cpan_global_install;

	@{ $global ? [] : [ qw(-L), $self->config->lib_dir ] };
}

method install_perl_build( @dists ) {
	my $global = $self->config->cpan_global_install;
	try {
	$self->platform->author_perl->script('cpm',
			qw(install),
			@{ $global ? [ qw(-g) ] : [ qw(-L), $self->config->build_tools_dir ] },
			@dists
	);
	} catch { };
	$self->cpanm( perl => $self->platform->author_perl, arguments => [
		qw(-qn),
		@{ $global ? [] : [ qw(-L), $self->config->build_tools_dir ] },
		@dists
	]);
}

method install_perl_deps( @dists ) {
	my $global = $self->config->cpan_global_install;
	try {
	$self->platform->build_perl->script(
		qw(cpm install),
		@{ $global ? [ qw(-g) ] : [ qw(-L), $self->config->lib_dir ] },
		@dists
	);

	$self->cpanm( perl => $self->platform->build_perl, arguments => [
		qw(-qn),
		$self->_install_perl_deps_cpanm_dir_arg,
		@dists
	]);
	} catch { };

	# Ignore modules that are installed already without checking CPAN for
	# version: `--skip-satisfied` .
	# This may need to be improved by looking for versions of modules that
	# are installed via cpanfile-git instead of from CPAN.
	$self->cpanm( perl => $self->platform->build_perl, arguments => [
		qw(-qn),
		qw(--skip-satisfied),
		$self->_install_perl_deps_cpanm_dir_arg,
		@dists
	]);
}

method _install_dzil() {
	try {
		$self->runner->system(
			$self->platform->author_perl->command(
				qw(-MDist::Zilla -e1),
			)
		);
	} catch {
		$self->install_perl_build(qw(Net::SSLeay Dist::Zilla));
	};
}

method _get_dzil_authordeps() {
	local $CWD = $self->directory;

	my ($dzil_authordeps, $dzil_authordeps_stderr, $dzil_authordeps_exit) = try {
		$self->runner->capture(
			$self->platform->author_perl->script_command(
				qw(dzil authordeps)
				# --missing
			)
		);
	} catch {};

	my $reader = my $other_reader = Module::Reader->new( inc => [
		'.',
		@{ $self->platform->author_perl->library_paths }
	]);
	my @dzil_authordeps =
		grep { ! ( try { $reader->module($_) } catch { 0 } ) }
		split /\n/, $dzil_authordeps;
}

method _install_dzil_authordeps() {
	my @dzil_authordeps = $self->_get_dzil_authordeps;
	if( @dzil_authordeps ) {
		$self->install_perl_build( @dzil_authordeps );
	}
}

method _get_dzil_listdeps() {
	local $CWD = $self->directory;
	my ($dzil_deps, $dzil_deps_stderr, $exit_listdeps) = $self->runner->capture(
		$self->platform->author_perl->script_command(
			qw(dzil listdeps)
			# --missing
		)
	);
	my @dzil_deps = grep {
		$_ !~ /
			^\W
			| ^Possibly\ harmless
			| ^Attempt\ to\ reload.*aborted
			| ^BEGIN\ failed--compilation\ aborted
			| ^Can't\ locate.*in\ \@INC
			| ^Compilation\ failed\ in\ require
			| ^Could\ not\ find\ sub\ .*\ exported\ by
		/x
	} split /\n/, $dzil_deps;
}

method _install_dzil_listdeps() {
	my @dzil_deps = $self->_get_dzil_listdeps;
	if( @dzil_deps ) {
		$self->install_perl_deps(@dzil_deps);
	}

}

method dzil_build_dir_relative() {
	File::Spec->abs2rel( $self->dzil_build_dir );
}

lazy dzil_build_dir => method() {
	File::Spec->catfile( $self->directory, qq(../_oberth/build-dir) );
};

method _dzil_build_in_dir() {
	local $CWD = $self->directory;

	say STDERR "Building dzil for @{[ $self->directory ]}";
	$self->platform->author_perl->script(
		qw(dzil build --in), $self->dzil_build_dir
	);
}

method _install_dzil_build() {
	$self->_dzil_build_in_dir;

	$self->cpanm( perl => $self->platform->build_perl, arguments => [
		qw(-qn),
		qw(--installdeps),
		$self->_install_perl_deps_cpanm_dir_arg,
		$self->dzil_build_dir_relative
	]);
}

method _dzil_has_plugin_test_podspelling() {
	return 1;

	load 'Test::DZil';

	my $temp_dir = tempdir( CLEANUP => 1 );

	my $dz = Test::DZil::Builder()->from_config(
		{ dist_root => $self->directory },
		{ tempdir_root => $temp_dir },
	);

	my @plugins = @{ $dz->plugins };

	scalar grep { ref $_ eq 'Dist::Zilla::Plugin::Test::PodSpelling' } @plugins;
}


method _install_dzil_spell_check_if_needed() {
	return unless $^O eq 'linux';

	require Oberth::Launch::RepoPackage::APT;
	if( $self->_dzil_has_plugin_test_podspelling ) {
		$self->runner->system(
			$self->platform->apt->install_packages_command(
				map {
					Oberth::Launch::RepoPackage::APT->new( name => $_ )
				} qw(aspell aspell-en)
			)
		);
	}
}

method setup_build() {
	$self->_install_dzil;
	$self->_install_dzil_authordeps;
	$self->_install_dzil_spell_check_if_needed;

	$self->_install_dzil_listdeps;
	$self->_install_dzil_build;
}

method install() {
	$self->_dzil_build_in_dir;

	$self->cpanm( perl => $self->platform->build_perl,
		command_cb => sub {
			shift->environment->add_environment( $self->environment );
		},
		arguments => [
			qw(--notest),
			qw(--no-man-pages),
			$self->_install_perl_deps_cpanm_dir_arg,
			$self->dzil_build_dir_relative
		],
	);
}

method run_test() {
	my $test_env = $self->test_environment;

	$self->_dzil_build_in_dir;

	if( $self->config->has_oberth_coverage ) {
		# Need to have at least Devel::Cover~1.31 for fix to
		# "Devel::Cover hangs when used with Function::Parameters"
		# GH#164 <https://github.com/pjcj/Devel--Cover/issues/164>.
		$self->cpanm( perl => $self->platform->build_perl, arguments => [
			qw(--no-man-pages),
			$self->_install_perl_deps_cpanm_dir_arg,
			qw(--notest),
			qw(Devel::Cover~1.31)
		]);

		$test_env->append_string(
			'HARNESS_PERL_SWITCHES', " -MDevel::Cover"
		);


		if( $self->config->oberth_coverage eq 'coveralls' ) {
			$self->cpanm( perl => $self->platform->build_perl, arguments => [
				qw(--no-man-pages),
				$self->_install_perl_deps_cpanm_dir_arg,
				qw(--notest),
				qw(Devel::Cover::Report::Coveralls)
			]);
		}
	}

	$self->cpanm( perl => $self->platform->build_perl,
		command_cb => sub {
			shift->environment->add_environment( $test_env );
		},
		arguments => [
			qw(--no-man-pages),
			$self->_install_perl_deps_cpanm_dir_arg,
			qw(--verbose),
			qw(--test-only),
			$self->dzil_build_dir_relative
	]);

	if( $self->config->has_oberth_coverage ) {
		local $CWD = $self->dzil_build_dir;
		if( $self->config->oberth_coverage eq 'coveralls' ) {
			$self->platform->build_perl->script(
				qw(cover), qw(-report coveralls)
			);
		} else {
			$self->platform->build_perl->script(
				qw(cover),
			);
		}
	}
}

lazy cpanm_latest_build_log => method() {
	my $homedir = $ENV{HOME}
		|| File::HomeDir->my_home
		|| join('', @ENV{qw(HOMEDRIVE HOMEPATH)}); # Win32

	if ( $^O eq 'MSWin32' ) {
		autoload "Win32";
		$homedir = Win32::GetShortPathName($homedir);
	}

	return "$homedir/.cpanm/build.log";
};

method cpanm( :$perl, :$command_cb = sub {}, :$arguments = [] ) {
	try {
		my $command = $perl->script_command( qw(cpanm), @$arguments );
		$command_cb->( $command );
		$self->runner->system( $command );
	} catch {
		say STDERR "cpanm failed. Dumping build.log.\n";
		say STDERR path( $self->cpanm_latest_build_log )->slurp_utf8;
		say STDERR "End of build.log.\n";
		die $_;
	};
}

1;
