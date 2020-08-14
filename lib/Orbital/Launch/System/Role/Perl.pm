use Modern::Perl;
package Orbital::Launch::System::Role::Perl;
# ABSTRACT: Role for Perls

use Mu::Role;
use Orbital::Transfer::Common::Setup;

use File::Spec;
use Orbital::Launch::Environment::Perl;

use Orbital::Launch::EnvironmentVariables;
use Object::Util magic => 0;

requires 'environment';
requires 'perl_path';
requires 'runner';

lazy author_perl => method() {
	$self->_get_perl_with_base_directory( $self->config->build_tools_dir );
};

lazy build_perl => method() {
	$self->_get_perl_with_base_directory( $self->config->lib_dir );
};

method _get_perl_with_base_directory( $directory ) {
	my $env = Orbital::Launch::EnvironmentVariables->new(
		parent => $self->environment,
	)->$_tap( 'prepend_path_list', 'PATH', [
		map {
			File::Spec->catfile( $directory, $_ )
		} @{ Orbital::Launch::BIN_DIRS() }
	]);
	Orbital::Launch::Environment::Perl->new(
		perl => $self->perl_path,
		runner => $self->runner,
		parent_environment => $env,
		library_paths => [
			map {
				File::Spec->catfile( $directory, $_ )
			} @{ ( Orbital::Launch::PERL_LIB_DIRS() ) }
		],
	);
}

1;
