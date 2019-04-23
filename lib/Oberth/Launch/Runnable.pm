use Modern::Perl;
package Oberth::Launch::Runnable;
# ABSTRACT: Base for runnable command

use Mu;
use Oberth::Manoeuvre::Common::Setup;
use Oberth::Manoeuvre::Common::Types qw(ArrayRef Str InstanceOf Bool);
use Types::TypeTiny qw(StringLike);

use Oberth::Launch::EnvironmentVariables;

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
	isa => InstanceOf['Oberth::Launch::EnvironmentVariables'],
	default => sub { Oberth::Launch::EnvironmentVariables->new },
);

has admin_privilege => (
	is => 'ro',
	isa => Bool,
	default => sub { 0 },
);

1;
