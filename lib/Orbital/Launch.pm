use strict;
use warnings;
package Orbital::Launch;
# ABSTRACT: Command line base for orbitalism

use Env qw(@PATH);
use Config;

use Orbital::Launch::FindLaunchSite;
use Orbital::Launch::FindLaunchHome;

use constant OP_DIR => Orbital::Launch::FindLaunchSite->get_launch_site_path_via_bin;
use constant BUILD_TOOLS_DIR => $ENV{CI}
	? File::Spec->catfile( Orbital::Launch::FindLaunchHome->get_home, qw(.orbital), qw(extlib))
	: File::Spec->catfile( OP_DIR , qw(extlib));

use constant BIN_DIRS => [
	'bin'
];
use constant PERL_LIB_DIRS => [
	File::Spec->catfile(qw(lib perl5)),
	File::Spec->catfile(qw(lib perl5), $Config::Config{archname}),
];

BEGIN {
	require File::Glob;
	our @VENDOR_LIB = File::Glob::bsd_glob( OP_DIR . "/vendor/*/lib");
	unshift @INC, @VENDOR_LIB;

	my $lib_dir = BUILD_TOOLS_DIR;
	unshift @INC,      File::Spec->catfile( $lib_dir, $_ ) for @{ (PERL_LIB_DIRS) };
	unshift @PATH,     File::Spec->catfile( $lib_dir, $_ ) for @{ (BIN_DIRS) };
}

use Carp::Always ();

use Mu;
use CLI::Osprey;

use ShellQuote::Any;
use File::Path qw(make_path);
use File::Which;
use Safe::Isa;

use Orbital::Transfer::Common::Setup;

use Orbital::Transfer::Config;
use Orbital::Transfer::Repo;

use Orbital::Transfer::Common::Types qw(AbsDir);

use Orbital::Payload::System::System::Debian;
use Orbital::Payload::System::System::MacOSHomebrew;
use Orbital::Payload::System::System::MSYS2;

has repo_url_to_repo => (
	is => 'ro',
	default => sub { +{} },
);

lazy platform => method() {
		my @opt = ( config => $self->config );
		my $system;
		if(  $^O eq 'darwin' && which('brew') ) {
			$system = Orbital::Payload::System::System::MacOSHomebrew->new( @opt );
		} elsif( $^O eq 'MSWin32' ) {
			$system = Orbital::Payload::System::System::MSYS2->new( @opt );
		} else {
			$system = Orbital::Payload::System::System::Debian->new( @opt );
		}
};

has config => (
	is => 'ro',
	default => sub {
		Orbital::Transfer::Config->new();
	},
);

option repo_directory => (
	is => 'ro',
	format => 's',
	isa => AbsDir,
	coerce => 1,
	default => sub {
		path('.');
	},
);

lazy repo => method() {
	my $repo = $self->repo_for_directory($self->repo_directory);
};

method _env() {
	my $test_data_repo_dir = $self->clone_git("https://github.com/project-renard/test-data.git");
	$ENV{RENARD_TEST_DATA_PATH} = $test_data_repo_dir;
}

method install() {
	$self->_env;

	# NOTE In Docker, these will be later chown'd to nonroot.
	$self->config->$_ for qw(base_dir build_tools_dir lib_dir external_dir);

	$self->platform->_install;

	unless( $self->config->cpan_global_install ) {
		$self->platform->build_perl->script(
			qw(cpm install -L), $self->config->lib_dir, qw(local::lib)
		)
	}

	$self->platform->_pre_run;

	my $repo = $self->repo;

	$self->platform->install_packages($repo);

	$self->install_recursively($repo, main => 1, native => 1);
	$self->install_recursively($repo, main => 1, native => 0 );

	$repo->setup_build;
}

method test() {
	$self->_env;

	$self->platform->_pre_run;

	my $repo = $self->repo;
	$self->test_repo($repo);
}

method run() {
	if( $ENV{CI} ) {
		# Carp under CI for debugging
		Carp::Always->import();
		# longer debug for Type::Tiny
		$Type::Tiny::DD = 1024;
	}

	try {
		$self->install;
	} catch {
		warn "Install failed: $_";
	};
}

subcommand 'test' => method() {
	$self->test;
};


method install_recursively($repo, :$main = 0, :$native = 0) {
	my @deps = $self->fetch_git($repo);
	for my $dep (@deps) {
		$self->install_recursively( $dep, native => $native  );
	}
	if( !$main ) {
		say STDERR "Installing @{[ $repo->directory ]}";
		$self->install_repo($repo, native => $native );
	}
}


use YAML;
method read_meta_file() {
	my $data = -f $self->config->meta_file
		? YAML::LoadFile($self->config->meta_file)
		: {};
}

method meta_get_installed_version( $repo ) {
	my $data = $self->read_meta_file;

	my $url = $self->get_repo_url( $repo );
	return $data->{repo}{ $url }{version} || '';
}

method meta_set_installed_version( $repo ) {
	my $data = $self->read_meta_file;

	my $url = $self->get_repo_url( $repo );
	my $describe = $self->git_repo_git_describe( $repo );

	$data->{repo}{ $url }{version} = $describe;

	YAML::DumpFile( $self->config->meta_file, $data );
}

use Git::Wrapper;
use List::AllUtils qw(first);
use Orbital::Payload::VCS::Git;
method git_repo_git_describe( $repo ) {
	my $git = Orbital::Payload::VCS::Git->new( directory => $repo->directory );
	my ($describe) = $git->_git_wrapper->describe( { always => 1 }, 'HEAD' );

	return $describe;
}
method get_repo_url( $repo ) {
	my $urls = $self->repo_url_to_repo;
	my $repo_url = first { $urls->{$_}->directory eq $repo->directory } keys %$urls;
}

method install_repo($repo, :$native = 0 ) {
	return if -f $repo->directory->child('installed');

	my $exit = 0;

	if( $native ) {
		$self->platform->install_packages($repo);
	} else {
		if( $self->meta_get_installed_version( $repo ) eq $self->git_repo_git_describe( $repo ) ) {
			say STDERR "Already installed @{[ $repo->directory ]} @ @{[ $self->meta_get_installed_version($repo) ]}";
			return 0; # exit success
		} else {
			$repo->$_call_if_can( uninstall => );
		}

		$repo->setup_build;
		$exit = $repo->install;

		say STDERR "Installed @{[ $repo->directory ]}";
		$repo->directory->child('installed')->touch;
		$self->meta_set_installed_version( $repo );
	}

	return $exit;
}

method test_repo($repo) {
	$repo->run_test;
}

method fetch_git($repo) {
	my @repos;

	my $deps = $repo->cpanfile_git_data;

	my @keys = keys %$deps;

	my $urls = $self->repo_url_to_repo;

	for my $module_name (@keys) {
		my $repos = $deps->{$module_name};

		my $repo;
		if( exists $urls->{ $repos->{git} } ) {
			$repo = $urls->{ $repos->{git} };
		} else {
			my $path = $self->clone_git( $repos->{git}, $repos->{branch} );

			$repo = $self->repo_for_directory($path);
			$urls->{ $repos->{git} } = $repo;
		}

		push @repos, $repo;
	}

	@repos;
}

method clone_git($url, $branch = 'master') {
	$branch = 'master' unless $branch;

	say STDERR "Cloning $url @ [branch: $branch]";
	my ($parts) = $url =~ m,^https?://[^/]+/(.+?)(?:\.git)?$,;
	my $path = File::Spec->rel2abs(File::Spec->catfile($self->config->external_dir, split(m|/|, $parts)));

	unless( -d $path ) {
		system(qw(git clone),
			qw(-b), $branch,
			$url,
			$path) == 0
		or die "Could not clone $url @ $branch";
		$self->platform->$_call_if_can( process_git_path => $path );
	}

	return $path;

}

method repo_for_directory($directory) {
	my $repo = Orbital::Transfer::Repo->new(
		directory => $directory,
		config => $self->config,
		platform => $self->platform,
	);

	require Orbital::Payload::Environment::Perl;
	Orbital::Payload::Environment::Perl->apply_roles_to_repo( $repo );

	Moo::Role->apply_roles_to_object( $repo, 'Orbital::Transfer::Repo::Role::DevopsYaml');
}


1;
