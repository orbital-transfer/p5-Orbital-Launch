use Modern::Perl;
package Orbital::Launch::Runnable;
# ABSTRACT: Base for runnable command

use Mu;
use Orbital::Transfer::Common::Setup;
use Orbital::Transfer::Common::Types qw(ArrayRef Str InstanceOf Bool);
use Types::TypeTiny qw(StringLike);

use Orbital::Launch::EnvironmentVariables;

use MooX::Role::CloneSet qw();
with qw(MooX::Role::CloneSet);

has command => (
	is => 'ro',
	isa => ArrayRef[StringLike],
	coerce => 1,
	required => 1,
);

has environment => (
	is => 'ro',
	isa => InstanceOf['Orbital::Launch::EnvironmentVariables'],
	default => sub { Orbital::Launch::EnvironmentVariables->new },
);

has admin_privilege => (
	is => 'ro',
	isa => Bool,
	default => sub { 0 },
);

1;
