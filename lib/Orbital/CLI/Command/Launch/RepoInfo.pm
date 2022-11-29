use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::Launch::RepoInfo;
# ABSTRACT: Dump repository info

use Mu;
use CLI::Osprey;
use Storable qw(dclone);
use Path::Tiny;

lazy finder => method() {
	eval "require Orbital::Payload::Meta::GitGot::RepoFinder"; ## no critic: 'ProhibitStringyEval'
	my $finder = Orbital::Payload::Meta::GitGot::RepoFinder->new;
};

method run() {
	## no critic: 'ProhibitStringyEval'
	eval q|
		use DDP; p $self->get_info( $self->repo_path );
	|;
}

has _info_cache => (
	is => 'ro',
	default => sub { +{} },
);

method get_info( $path ) {
	my $info;
	return $self->_info_cache->{$path} if exists $self->_info_cache->{$path};

	require Orbital::Transfer::Repo;
	my $repo = Orbital::Transfer::Repo->new(
		directory => $path,
		config => undef,
		platform => undef,
	);

	require Orbital::Payload::Env::Perl;
	Orbital::Payload::Env::Perl->apply_roles_to_repo( $repo );

	Moo::Role->apply_roles_to_object( $repo, 'Orbital::Transfer::Repo::Role::DevopsYaml');

	$info->{path} = path($path);
	try_tt {
		$info->{devops} = $repo->devops_data;
	} catch_tt {
	};
	my $deps = dclone($repo->cpanfile_git_data);

	for my $name ( keys %{ $deps } ) {
		my $github = Orbital::Payload::Serv::GitHub::Repo->new(
			uri => $deps->{$name}{git},
		);

		my $dep_path = $self->finder->find_path( $github );
		warn "No path found for $name" unless $dep_path;

		$info->{deps}{$name} = $self->get_info(
			$dep_path,
		);
	}

	my ($gitgot_for_path) = grep { $_->repo_path eq $info->{path} } @{ $self->finder->gitgot->data };
	$info->{gitgot}{tags} = $gitgot_for_path->repo_tags;

	$self->_info_cache->{$path} = $info;
}

## no critic: 'ProhibitStringyEval'
eval q|
with qw(Orbital::CLI::Command::Role::Option::RepoPath);
|;

1;
