use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::Launch::Vagrant::ProjectDirectories;
# ABSTRACT: List project directories

use Orbital::Transfer::Common::Setup;
use Mu;
use CLI::Osprey;

option gitgot_tag => (
	is => 'ro',
	required => 1,
	format => 's',
);

lazy gitgot => method() {
	eval "require Orbital::Payload::Tool::GitGot"; ## no critic: 'ProhibitStringyEval'
	Orbital::Payload::Tool::GitGot->new;
};

method run() {
	my @directories;
	for my $repo (@{ $self->gitgot->repos }) {
		push @directories, $repo->path
			if -d $repo->path
				&& grep { $_ eq $self->gitgot_tag } @{ $repo->tags };
	}
	print join "\0", @directories;
}


## no critic: 'ProhibitStringyEval'
eval q|
with qw(Orbital::CLI::Command::Role::Option::RepoPath);
|;

1;
