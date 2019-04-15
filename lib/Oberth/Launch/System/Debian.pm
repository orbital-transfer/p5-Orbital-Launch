use Modern::Perl;
package Oberth::Launch::System::Debian;
# ABSTRACT: Debian-based system

use Mu;
use Oberth::Manoeuvre::Common::Setup;
use Oberth::Launch::System::Debian::Meson;

use Oberth::Launch::PackageManager::APT;
use Oberth::Launch::RepoPackage::APT;

use Oberth::Launch::EnvironmentVariables;
use Object::Util;

lazy apt => method() {
	Oberth::Launch::PackageManager::APT->new(
		runner => $self->runner
	);
};

lazy x11_display => method() {
	':99.0';
};

lazy environment => method() {
	Oberth::Launch::EnvironmentVariables
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
	my @packages = map {
		Oberth::Launch::RepoPackage::APT->new( name => $_ )
	} qw(xvfb xauth);
	$self->runner->system(
		$self->apt->install_packages_command(@packages)
	);
}

method install_packages($repo) {
	my @packages = map {
		Oberth::Launch::RepoPackage::APT->new( name => $_ )
	} @{ $repo->debian_get_packages };

	$self->runner->system(
		$self->apt->install_packages_command(@packages)
	) if @packages;

	if( grep { $_->name eq 'meson' } @packages ) {
		Oberth::Launch::System::Debian::Meson->setup;
	}
}

with qw(
	Oberth::Launch::System::Role::Config
	Oberth::Launch::System::Role::DefaultRunner
	Oberth::Launch::System::Role::PerlPathCurrent
	Oberth::Launch::System::Role::Perl
);

1;
