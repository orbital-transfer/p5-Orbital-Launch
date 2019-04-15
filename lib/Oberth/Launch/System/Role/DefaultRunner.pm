use Modern::Perl;
package Oberth::Launch::System::Role::DefaultRunner;
# ABSTRACT: Default runner

use Mu::Role;
use Oberth::Manoeuvre::Common::Setup;

use Oberth::Launch::Runner::Default;

lazy runner => method() {
	Oberth::Launch::Runner::Default->new;
};

1;
