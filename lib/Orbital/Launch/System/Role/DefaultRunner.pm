use Modern::Perl;
package Orbital::Launch::System::Role::DefaultRunner;
# ABSTRACT: Default runner

use Mu::Role;
use Orbital::Transfer::Common::Setup;

use Orbital::Launch::Runner::Default;

lazy runner => method() {
	Orbital::Launch::Runner::Default->new;
};

1;
