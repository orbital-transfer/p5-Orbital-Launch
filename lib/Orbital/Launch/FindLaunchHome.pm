use strict;
use warnings;
package Orbital::Launch::FindLaunchHome;
# ABSTRACT: Find launch home directory

use File::Spec;

sub get_home {
	my $home_dir = $ENV{HOME} || $ENV{USERPROFILE};

	return $home_dir;
}

1;
