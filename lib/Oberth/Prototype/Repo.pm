use Modern::Perl;
package Oberth::Prototype::Repo;
# ABSTRACT: Represent the top level of a code base repo

use Mu;

use Oberth::Manoeuvre::Common::Setup;
use Oberth::Manoeuvre::Common::Types qw(AbsDir);

has directory => (
	is => 'ro',
	required => 1,
	coerce => 1,
	isa => AbsDir,
);

has config => (
	is => 'ro',
	required => 1,
);

lazy runner => method() {
	$self->config->platform->runner;
};

1;
