use Orbital::Transfer::Common::Setup;
package Orbital::Launch::CIGen;
# ABSTRACT: Generate CI configurations

use Orbital::Transfer::Common::Setup;
use Moo;
use CLI::Osprey;

use Orbital::Launch::CIGen::AppVeyor;
use Orbital::Launch::CIGen::TravisCI;
use Orbital::Launch::CIGen::GitHubActions;

method run() {
	my $paths_to_data = {
		#'appveyor.yml' => ${ Orbital::Launch::CIGen::AppVeyor->section_data('appveyor.yml') },
		#'.travis.yml'  => ${ Orbital::Launch::CIGen::TravisCI->section_data('.travis.yml') },
		'.github/workflows/orbital-transfer.yml'  => ${ Orbital::Launch::CIGen::GitHubActions->section_data('orbital-transfer.yml') },
	};
	while( my ($path, $data) = each %$paths_to_data ) {
		my $path_obj = path($path);
		$path_obj->parent->mkpath;
		$path_obj->spew_utf8( $data );
	}
}

1;
