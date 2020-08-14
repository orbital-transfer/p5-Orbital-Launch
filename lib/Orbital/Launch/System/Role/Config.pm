use Modern::Perl;
package Orbital::Launch::System::Role::Config;
# ABSTRACT: Has config

use Mu::Role;
use Orbital::Transfer::Common::Setup;

has config => (
	is => 'ro',
	required => 1,
);

1;
