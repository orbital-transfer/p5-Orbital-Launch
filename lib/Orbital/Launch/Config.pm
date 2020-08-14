use Modern::Perl;
package Orbital::Launch::Config;
# ABSTRACT: Configuration

use Mu;

use Orbital::Transfer::Common::Setup;
use Path::Tiny;
use FindBin;
use Env qw($ORBITAL_GLOBAL_INSTALL $ORBITAL_COVERAGE);

lazy base_dir => sub {
	my $p = path('..')->absolute;
	$p->mkpath;
	$p->realpath;
};

lazy build_tools_dir => sub {
	my ($self) = @_;
	my $p = $self->base_dir->child('_orbital/author-local');
	$p->mkpath;
	$p->realpath;
};

lazy lib_dir => sub {
	my ($self) = @_;
	my $p = $self->base_dir->child('local');
	$p->mkpath;
	$p->realpath;
};

lazy external_dir => sub {
	my ($self) = @_;
	my $p = $self->base_dir->child(qw(_orbital external));
	$p->mkpath;
	$p->realpath;
};

has cpan_global_install => (
	is => 'ro',
	default => sub {
		my $global = $ORBITAL_GLOBAL_INSTALL // 0;
	},
);

method has_orbital_coverage() {
	exists $ENV{ORBITAL_COVERAGE} && $ENV{ORBITAL_COVERAGE};
}

method orbital_coverage() {
	$ENV{ORBITAL_COVERAGE};
}

1;
