use Modern::Perl;
package Orbital::Launch::System::Role::PerlPathCurrent;
# ABSTRACT: Role to use current running Perl as Perl path

use Mu::Role;
use Config;
use Orbital::Transfer::Common::Setup;

lazy 'perl_path' => method() {
	# See documentation at
	#   $ perldoc -v '$^X'
	my $secure_perl_path = $Config{perlpath};
	if ($^O ne 'VMS') {
		$secure_perl_path .= $Config{_exe}
		unless $secure_perl_path =~ m/$Config{_exe}$/i;
	}
	$secure_perl_path;
};

1;
