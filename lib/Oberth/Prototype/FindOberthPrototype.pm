use strict;
use warnings;
package Oberth::Prototype::FindOberthPrototype;
# ABSTRACT: Find oberth-prototype directory

use FindBin;
use File::Spec;
use Cwd qw(realpath);

sub get_oberth_prototype_path_via_bin {
	my $directory = $FindBin::Bin;
	until( -r File::Spec->catfile( $directory, qw(maint oberth-prototype-repo) ) ) {
		$directory = realpath( File::Spec->catfile( $directory, '..' ) );
		last if $directory eq '/';
	}

	my $op_dir = $directory;
}

1;
