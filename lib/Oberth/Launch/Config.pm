use Modern::Perl;
package Oberth::Launch::Config;
# ABSTRACT: Configuration

use Mu;

use Oberth::Manoeuvre::Common::Setup;
use Path::Tiny;
use FindBin;
use Env qw($OBERTH_GLOBAL_INSTALL $OBERTH_COVERAGE);

has base_dir => (
	is => 'ro',
	default => sub {
		my $p = path('..')->absolute;
		$p->mkpath;
		$p->realpath;
	},
);

has build_tools_dir => (
	is => 'ro',
	default => sub {
		my ($self) = @_;
		my $p = $self->base_dir->child('_oberth/author-local');
		$p->mkpath;
		$p->realpath;
	},
);

has lib_dir => (
	is => 'ro',
	default => sub {
		my ($self) = @_;
		my $p = $self->base_dir->child('local');
		$p->mkpath;
		$p->realpath;
	},
);

has external_dir => (
	is => 'ro',
	default => sub {
		my ($self) = @_;
		my $p = $self->base_dir->child(qw(_oberth external));
		$p->mkpath;
		$p->realpath;
	},
);

has cpan_global_install => (
	is => 'ro',
	default => sub {
		my $global = $OBERTH_GLOBAL_INSTALL // 0;
	},
);

method has_oberth_coverage() {
	exists $ENV{OBERTH_COVERAGE} && $ENV{OBERTH_COVERAGE};
}

method oberth_coverage() {
	$ENV{OBERTH_COVERAGE};
}

1;
