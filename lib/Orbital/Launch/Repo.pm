use Modern::Perl;
package Orbital::Launch::Repo;
# ABSTRACT: Represent the top level of a code base repo

use Mu;

use Orbital::Transfer::Common::Setup;
use Orbital::Transfer::Common::Types qw(AbsDir);

has directory => (
	is => 'ro',
	required => 1,
	coerce => 1,
	isa => AbsDir,
);

has [ qw(config platform) ] => (
	is => 'ro',
	required => 1,
);

lazy runner => method() {
	$self->platform->runner;
};

1;
