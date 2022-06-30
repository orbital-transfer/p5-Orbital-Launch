use strict;
use warnings;
package Orbital::Launch::Command::Bootstrap;
# ABSTRACT: Bootstrap a repo

use feature 'say';
use Orbital::Launch::FindLaunchSite;
use Orbital::Launch::FindLaunchHome;
use Cwd qw(getcwd);
use IPC::Open3;
use File::Spec;
use File::Find;
use File::Path qw(make_path);
use File::Glob;
use File::Copy;
use File::Basename;
use Config;
use Env qw(@PATH @PERL5LIB);
use constant COMMANDS => (
	'auto' => \&run_auto,
	'setup' => \&run_setup,
	'generate-cpanfile' => \&run_generate_cpanfile,
	'install-deps-from-cpanfile' => \&run_install_deps_from_cpanfile,
	'docker-install-apt' => \&run_docker_install_apt,
);

sub new {
	my ($package) = @_;

	my $dir;
	my $global = 0;
	my $command;

	my $commands_re = qr/^(@{[ join("|", keys %{ {COMMANDS()} }) ]})$/;

	while(@ARGV) {
		my $arg = shift @ARGV;
		if( $arg eq '--dir' ) {
			$dir = shift @ARGV;
		} elsif( $arg eq '--global' ) {
			$global = 1;
		} elsif( $arg =~ $commands_re ) {
			$command = $arg;
		}
	}

	die "need command: $commands_re" unless $command;

	my $op_dir = Orbital::Launch::FindLaunchSite->get_launch_site_path_via_bin;

	my $perl_abs_dir = File::Spec->rel2abs(dirname($^X));
	if( $perl_abs_dir =~ m,\Q\\Strawberry\\perl\\bin\E, ) {
		# perl.exe in
		# \Strawberry\perl\bin\perl.exe
		# compiler in
		# \Strawberry\c\bin\gcc
		# because this compiler is needed for building modules
		my $c_bin = File::Spec->rel2abs(
			File::Spec->catfile($perl_abs_dir,
				'..', '..', 'c', 'bin') );
		unshift @PATH, $c_bin;
	}

	my ($bin_dir, $lib_dir);
	if( ! $global ) {
		if( $ENV{CI} ) {
			$dir = File::Spec->catfile( Orbital::Launch::FindLaunchHome->get_home, qw(.orbital), qw(extlib));
		} else {
			$dir = File::Spec->catfile( $op_dir, qw(extlib)) unless $dir;
		}

		$bin_dir = File::Spec->catfile($dir, qw(bin));
		make_path $bin_dir;

		unshift @PATH, $bin_dir;

		$lib_dir = File::Spec->catfile($dir, qw(lib));
		make_path $lib_dir;

		unshift @PERL5LIB, File::Spec->catfile( $dir, qw(lib perl5) );
		unshift @PERL5LIB, File::Spec->catfile( $dir, qw(lib perl5), $Config{archname});
	}

	bless {
		command => $command,
		orbitalism_dir => $op_dir,
		dir => $dir,
		global => $global,
		bin_dir => $bin_dir,
		lib_dir => $lib_dir,
		vendor_dir => File::Spec->catfile($op_dir, qw(vendor)),
		vendor_external_dir => File::Spec->catfile($op_dir, qw(vendor-external)),
	}, $package;
}

sub run_auto {
	my ($self) = @_;

	$self->run_setup;
	$self->run_generate_cpanfile;
	$self->run_install_deps_from_cpanfile;
}

sub run_setup {
	my ($self) = @_;

	$self->{cpm} = 'cpm';
	$self->install_self_contained_cpm unless $self->has_cpm;

	$self->log('Installing cpanminus using cpm');
	$self->_cpm(
		'--resolver', '02packages,http://cpan.metacpan.org',
		qw(App::cpanminus),
	) unless $self->has_cpanm;

	$self->log('Installing prereq scanner');
	$self->_cpanm(
		#qw(Perl::PrereqScanner::Lite),
		#qw(Perl::PrereqScanner),
		qw(App::scan_prereqs_cpanfile),
	);

	# if
	# - have a .repoid in current directory,
	# - git executable
	if( -f '.repoid' && system(qw(git --version)) == 0 ) {
		my @dirs = $self->get_vendor_dirs;
		my $abs_path = File::Spec->rel2abs('.');
		my $repoid = $self->slurp_file( '.repoid' );
		for my $vendor_dir (@dirs) {
			my $vendor_repoid_path = File::Spec->catfile($vendor_dir, '.repoid');
			my $vendor_repoid = $self->slurp_file( $vendor_repoid_path );
			if( $repoid eq $vendor_repoid ) {
				$self->log("Repo ID $repoid matches with $vendor_dir. Using current HEAD.");
				system( qw(git),
					"--git-dir=@{[ File::Spec->catfile($abs_path, '.git') ]}",
					"--work-tree=$vendor_dir",
					qw( reset --hard )
				);
			}
		}
	}
}

sub slurp_file {
	my ($self, $path) = @_;
	open my $fh, '<', $path or die;
	local $/ = undef;
	my $content = <$fh>;
	close $fh;
	return $content;
}

sub _cpm {
	my ($self, @args) = @_;

	$self->system( $^X, qw(-S), $self->{cpm}, qw(install),
		qw(--verbose),
		@{ $self->{global} ? [ qw(-g) ] : [ qw(-L), $self->{dir}, ] },
		@args,
	);
}

sub _cpanm {
	my ($self, @args) = @_;

	$self->system( $^X, qw(-S), qw(cpanm),
		qw(-nq),
		@{ $self->{global} ? [] : [ qw(-L), $self->{dir}, ] },
		@args,
	);
}

sub create_cpanfile_in_directory {
	my ($self, $dir) = @_;

	$self->log("Creating cpanfile for $dir");

	my ($wtr, $rdr, $err);

	my $cpanfile = IO::File->new(File::Spec->catfile($dir, 'cpanfile'), 'w');

	my $old_pwd = getcwd;

	chdir $dir;
	my $rel_dir = File::Spec->abs2rel($dir);
	my $pid = open3($wtr, $rdr, $err,
		qw(scan-prereqs-cpanfile),
		qq(--ignore=)
			. join(',',
				qw(
					extlib
					vendor
					vendor-external
				)
			),
		"--dir=$rel_dir",
	);

	close $wtr;
	while(<$rdr>) {
		next if /Orbital/;
		print $cpanfile $_;
	}
	waitpid( $pid, 0 );

	chdir $old_pwd;

	my $child_exit_status = $? >> 8;
}

sub run_generate_cpanfile {
	my ($self) = @_;

	$self->create_cpanfile_in_directory($self->{orbitalism_dir});

	my @dirs = $self->get_vendor_dirs;
	say @dirs;
	for my $vendor_dir (@dirs) {
		$self->create_cpanfile_in_directory($vendor_dir);
	}
}

sub get_vendor_dirs {
	my ($self) = @_;

	my $vendor_dir = $self->{vendor_dir};
	my @dirs = grep { -d } <$vendor_dir/*>;
}

sub _install_cpanfile {
	my ($self, $cpanfile) = @_;

	$self->_cpm(
		"--cpanfile=$cpanfile"
	);

	$self->_cpanm(
		qw(--installdeps .),
		qw(--cpanfile), $cpanfile,
	);
}

sub run_install_deps_from_cpanfile {
	my ($self) = @_;

	$self->_install_cpanfile(File::Spec->catfile($self->{orbitalism_dir}, 'cpanfile'));

	my @dirs = $self->get_vendor_dirs;
	for my $vendor_dir (@dirs) {
		$self->_install_cpanfile(File::Spec->catfile($vendor_dir, 'cpanfile'));
	}
}

sub run_docker_install_apt {
	my ($self) = @_;
	$self->system(<<'EOF');
	apt-get update && \
		xargs apt-get install -y --no-install-recommends \
		< /launch-site/maint/docker-debian-packages
EOF
}

sub run {
	my ($self) = @_;

	my $cmd = { COMMANDS }->{ $self->{command} };

	die "command invalid: @{[ $self->{command} ]}" unless $cmd;

	$self->$cmd();
}

sub get_exit_status {
	my ($self, $command, @args) = @_;
	if( $^O eq 'MSWin32') {
		return $self->system( $command, @args );
	}
	my ($wtr, $rdr, $err);
	my $child_exit_status = 1;
	eval {
		$self->log("Using open3: $command @args");
		my $pid = open3($wtr, $rdr, $err,
			$command, @args);

		close $wtr;
		print while(<$rdr>);

		waitpid( $pid, 0 );
		$child_exit_status = $? >> 8;
	};
	return $child_exit_status;
}

sub has_cpan {
	my ($self) = @_;
	return 0 == $self->get_exit_status( $^X, qw(-S), qw(cpan -v));
}

sub has_cpanm {
	my ($self) = @_;
	return 0 == $self->get_exit_status( $^X, qw(-S), qw(cpanm -V));
}

sub has_cpm {
	my ($self) = @_;
	return 0 == $self->get_exit_status( $^X, qw(-S), $self->{cpm}, qw(--version));
}

sub install_self_contained_cpm {
	my ($self) = @_;

	$self->{cpm} = File::Spec->catfile( $self->{bin_dir}, qw(cpm) );

	$self->log('Copying cpm from vendor-external');
	copy( File::Spec->catfile($self->{vendor_external_dir}, qw(cpm cpm)),  $self->{cpm} ) or die "Could not copy cpm: $!";
	chmod 0755, $self->{cpm};
	#$self->system( $^X, qw(-S), qw(pl2bat), $self->{cpm} ) if $^O eq 'MSWin32';
	die "Could not install cpm: $!" unless $self->has_cpm;
}

sub log {
	my ($self, $message) = @_;
	say STDERR "Bootstrap: $message";
}

sub system {
	my ($self, @args) = @_;
	$self->log("Running command: @args");
	return system(@args);
}

1;
