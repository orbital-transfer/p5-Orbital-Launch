package TestRepo;
# ABSTRACT: Helper for testing a repository

use Modern::Perl;
use Test::Most;
use File::Temp qw(tempdir);
use Capture::Tiny qw(capture_merged);
use Path::Tiny;

sub test_github {
	my ($class, $repo_slug) = @_;
	subtest "Check $repo_slug" => sub {
		TODO: {
		todo_skip 'Skip on Windows (for now)', 1 if $^O eq 'MSWin32';

		require Orbital::Launch;

		my $temp_dir = tempdir( CLEANUP => 1 );

		my $github_uri = "https://github.com/${repo_slug}.git";
		note "Downloading $github_uri";
		my ($merged_git) = capture_merged { system( qw(git clone), $github_uri, $temp_dir); };
		note $merged_git;

		# Do not run coverage for repos under testing.
		delete $ENV{ORBITAL_COVERAGE};
		# If running under CI, share the same base directory to speed up install.
		my @use_base_dir =
			exists $ENV{ORBITAL_TEST_DIR}
			? ( base_dir => path($ENV{ORBITAL_TEST_DIR})->parent->absolute )
			: ();
		my $config = Orbital::Launch::Config->new( @use_base_dir );
		my $launch = Orbital::Launch->new( repo_directory => $temp_dir, config => $config );
		my ($merged, @result);
		lives_ok {
			($merged, @result) = capture_merged {
				note "Running install";
				$launch->install;
				note "Running test";
				$launch->test;
			};
		};

		note $merged;
		pass if @result;
		}
	};
}

1;
