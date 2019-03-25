use Modern::Perl;
package Oberth::CLI::Container::Launch;
# ABSTRACT: Container for Launch

use Oberth::Manoeuvre::Common::Setup;

method commands() {
	return +{
		'launch' => 'Oberth::CLI::Command::Launch',
		'launch/repo-info' => 'Oberth::CLI::Command::Launch::RepoInfo',
	}
}

1;
