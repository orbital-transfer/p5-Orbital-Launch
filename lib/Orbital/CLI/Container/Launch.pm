use Modern::Perl;
package Orbital::CLI::Container::Launch;
# ABSTRACT: Container for Launch

use Orbital::Transfer::Common::Setup;

method commands() {
	return +{
		#'launch' => 'Orbital::CLI::Command::Launch',
		'launch' => 'Orbital::Launch',
		'launch/repo-info' => 'Orbital::CLI::Command::Launch::RepoInfo',
		'launch/pod-site' => 'Orbital::CLI::Command::Launch::PodSite',
		'launch/vagrant' => 'Orbital::CLI::Command::Launch::Vagrant',
		'launch/vagrant/helper' => 'Orbital::CLI::Command::Launch::Vagrant::Helper',
		'launch/vagrant/project-directories' => 'Orbital::CLI::Command::Launch::Vagrant::ProjectDirectories',
		'launch/cigen' => 'Orbital::Launch::CIGen',
	}
}

1;
