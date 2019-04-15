use Modern::Perl;
package Oberth::Launch::System::Role::PerlPathCurrent;
# ABSTRACT: Role to use current running Perl as Perl path

use Mu::Role;
use Oberth::Manoeuvre::Common::Setup;

lazy 'perl_path' => method() {
	$^X;
};

1;
