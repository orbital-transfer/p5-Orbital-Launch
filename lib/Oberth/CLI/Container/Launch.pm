use Modern::Perl;
package Oberth::CLI::Container::Launch;
# ABSTRACT: Container for Launch

use Oberth::Manoeuvre::Common::Setup;

method commands() {
	return +{
		#'launch' => 'Oberth::CLI::Command::Launch',
		'launch' => 'Oberth::Launch',
		'launch/repo-info' => 'Oberth::CLI::Command::Launch::RepoInfo',
		'launch/pod-site' => 'Oberth::CLI::Command::Launch::PodSite',
		'launch/vagrant' => 'Oberth::CLI::Command::Launch::Vagrant',
		'launch/vagrant/helper' => 'Oberth::CLI::Command::Launch::Vagrant::Helper',
		'launch/vagrant/project-directories' => 'Oberth::CLI::Command::Launch::Vagrant::ProjectDirectories',
	}
}

1;
