use strict;
use warnings;
package Orbital::Launch::FindLaunchSite;
# ABSTRACT: Find launch-site directory

use FindBin;
use File::Spec;
use Cwd qw(realpath);

sub get_launch_site_path_via_bin {
	my $directory = $FindBin::Bin;
	until( -r File::Spec->catfile( $directory, qw(maint launch-site-repo) ) ) {
		$directory = realpath( File::Spec->catfile( $directory, '..' ) );
		last if $directory eq '/';
	}

	my $op_dir = $directory;
}

1;
