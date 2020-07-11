use Modern::Perl;
package Oberth::Launch::Repo::Role::PerlEnvironment;
# ABSTRACT: A role for running the right environment for Perl

use Mu::Role;

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

1;
