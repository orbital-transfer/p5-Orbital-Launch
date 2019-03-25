use Oberth::Manoeuvre::Common::Setup;
package Oberth::CLI::Command::Launch::RepoInfo;
# ABSTRACT: Dump repository info

use Modern::Perl;
use Mu;
use CLI::Osprey;
use Clone qw(clone);
use Try::Tiny;
use Path::Tiny;

method run() {
	## no critic: 'ProhibitStringyEval'
	eval q|
		use DDP; p $self->get_info( $self->repo_path );
	|;
}

lazy gitgot_github => method() {
	eval "require Oberth::Block::Meta::GitGot"; ## no critic: 'ProhibitStringyEval'

	my $gitgot = Oberth::Block::Meta::GitGot->new;
	my @gitgot_github = map {
		try {
			die unless defined $_->repo_url;
			+{
				gitgot => $_,
				github_repo => Oberth::Block::Service::GitHub::Repo->new(
					uri => $_->repo_url,
				),
			}
		} catch {
			();
		};
	} @{ $gitgot->data };

	\@gitgot_github;
};

lazy git_scp_to_path => method() {
	+{
		map {
			$_->{github_repo}->git_scp_uri
				=> $_->{gitgot}->repo_path
		} @{ $self->gitgot_github }
	};
};

has _info_cache => (
	is => 'ro',
	default => sub { +{} },
);

method get_info( $path ) {
	my $info;
	return $self->_info_cache->{$path} if exists $self->_info_cache->{$path};

	require Oberth::Prototype::Repo;
	my $repo = Oberth::Prototype::Repo->new(
		directory => $path,
		config => undef,
		platform => undef,
	);

	Moo::Role->apply_roles_to_object( $repo, 'Oberth::Prototype::Repo::Role::DistZilla');
	Moo::Role->apply_roles_to_object( $repo, 'Oberth::Prototype::Repo::Role::CpanfileGit');
	Moo::Role->apply_roles_to_object( $repo, 'Oberth::Prototype::Repo::Role::DevopsYaml');

	$info->{path} = path($path);
	try {
		$info->{devops} = $repo->devops_data;
	} catch {
	};
	my $deps = clone($repo->cpanfile_git_data);

	for my $name ( keys %{ $deps } ) {
		my $github = Oberth::Block::Service::GitHub::Repo->new(
			uri => $deps->{$name}{git},
		);

		my $dep_path = $self->git_scp_to_path->{ $github->git_scp_uri };

		$info->{deps}{$name} = $self->get_info(
			$dep_path,
		);
	}

	$self->_info_cache->{$path} = $info;
}

## no critic: 'ProhibitStringyEval'
eval q|
with qw(Oberth::CLI::Command::Role::Option::RepoPath);
|;

1;
