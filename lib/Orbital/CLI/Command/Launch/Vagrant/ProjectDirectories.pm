use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::Launch::Vagrant::ProjectDirectories;
# ABSTRACT: List project directories

use Modern::Perl;
use Mu;
use CLI::Osprey;
use Try::Tiny;
use Path::Tiny;

option gitgot_tag => (
	is => 'ro',
	required => 1,
	format => 's',
);

lazy gitgot => method() {
	eval "require Orbital::Payload::Meta::GitGot"; ## no critic: 'ProhibitStringyEval'
	Orbital::Payload::Meta::GitGot->new;
};

method run() {
	my @directories;
	for my $repo (@{ $self->gitgot->data }) {
		push @directories, $repo->repo_path
			if -d $repo->repo_path
				&& grep { $_ eq $self->gitgot_tag } @{ $repo->repo_tags };
	}
	print join "\0", @directories;
}


## no critic: 'ProhibitStringyEval'
eval q|
with qw(Orbital::CLI::Command::Role::Option::RepoPath);
|;

1;
