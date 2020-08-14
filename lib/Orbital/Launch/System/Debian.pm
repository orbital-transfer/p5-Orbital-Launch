use Modern::Perl;
package Orbital::Launch::System::Debian;
# ABSTRACT: Debian-based system

use Mu;
use Orbital::Transfer::Common::Setup;
use Orbital::Launch::System::Debian::Meson;
use Orbital::Launch::System::Docker;

use Orbital::Launch::PackageManager::APT;
use Orbital::Launch::RepoPackage::APT;

use Orbital::Launch::EnvironmentVariables;
use Object::Util magic => 0;

lazy apt => method() {
	Orbital::Launch::PackageManager::APT->new(
		runner => $self->runner
	);
};

lazy x11_display => method() {
	':99.0';
};

lazy environment => method() {
	Orbital::Launch::EnvironmentVariables
		->new
		->$_tap( 'set_string', 'DISPLAY', $self->x11_display );
};

method _prepare_x11() {
	#system(qw(sh -e /etc/init.d/xvfb start));
	unless( fork ) {
		exec(qw(Xvfb), $self->x11_display);
	}
	sleep 3;
}

method _pre_run() {
	$self->_prepare_x11;
}

method _install() {
	if( Orbital::Launch::System::Docker->is_inside_docker ) {
		# create a non-root user
		say STDERR "Creating user nonroot (this should only occur inside Docker)";
		system(qw(useradd -m notroot));
		system(qw(chown -R notroot:notroot /build));
	}
	my @packages = map {
		Orbital::Launch::RepoPackage::APT->new( name => $_ )
	} qw(xvfb xauth);
	$self->runner->system(
		$self->apt->install_packages_command(@packages)
	) unless $self->apt->are_all_installed(@packages);
}

method install_packages($repo) {
	my @packages = map {
		Orbital::Launch::RepoPackage::APT->new( name => $_ )
	} @{ $repo->debian_get_packages };

	$self->runner->system(
		$self->apt->install_packages_command(@packages)
	) if @packages && ! $self->apt->are_all_installed(@packages);

	if( grep { $_->name eq 'meson' } @packages ) {
		my $meson = Orbital::Launch::System::Debian::Meson->new(
			runner => $self->runner,
			platform => $self,
		);
		$meson->install_pip3_apt($self->apt);
		$meson->setup;
	}
}

method process_git_path($path) {
	if( Orbital::Launch::System::Docker->is_inside_docker ) {
		system(qw(chown -R notroot:notroot), $path);
	}
}

with qw(
	Orbital::Launch::System::Role::Config
	Orbital::Launch::System::Role::DefaultRunner
	Orbital::Launch::System::Role::PerlPathCurrent
	Orbital::Launch::System::Role::Perl
);

1;
