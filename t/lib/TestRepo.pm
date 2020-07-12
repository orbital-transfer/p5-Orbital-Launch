package TestRepo;
# ABSTRACT: Helper for testing a repository

use Modern::Perl;
use Test::Most;
use Oberth::Launch;
use File::Temp qw(tempdir);
use Capture::Tiny qw(capture_merged);

sub test_github {
	my ($class, $repo_slug) = @_;
	subtest "Check $repo_slug" => sub {
		my $temp_dir = tempdir( CLEANUP => 1 );

		my $github_uri = "https://github.com/${repo_slug}.git";
		note "Downloading $github_uri";
		my ($merged_git) = capture_merged { system( qw(git clone), $github_uri, $temp_dir); };
		note $merged_git;

		my $launch = Oberth::Launch->new( repo_directory => $temp_dir );
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
	};
}

1;
