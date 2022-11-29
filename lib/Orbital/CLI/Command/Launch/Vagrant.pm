use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::Launch::Vagrant;
# ABSTRACT: Vagrant

use Orbital::Transfer::Common::Setup;
use Mu;
use CLI::Osprey;

method run() {
	...
}


## no critic: 'ProhibitStringyEval'
eval q|
with qw(Orbital::CLI::Command::Role::Option::RepoPath);
|;

1;
