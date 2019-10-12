use Modern::Perl;
package Oberth::Launch::Config;
# ABSTRACT: Configuration

use Mu;

use Oberth::Manoeuvre::Common::Setup;
use Path::Tiny;
use FindBin;
use Env qw($OBERTH_GLOBAL_INSTALL $OBERTH_COVERAGE);

has build_tools_dir => (
	is => 'ro',
	default => sub { path('../_oberth/author-local')->absolute },
);

has lib_dir => (
	is => 'ro',
	default => sub { path('../_oberth/local')->absolute },
);

has external_dir => (
	is => 'ro',
	default => sub {
		File::Spec->catfile( '..', qw(_oberth external) );
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
