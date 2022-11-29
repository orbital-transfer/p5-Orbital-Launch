use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::Launch::Vagrant;
# ABSTRACT: Vagrant

use Mu;
use CLI::Osprey;
use Try::Tiny;
use Path::Tiny;

method run() {
	...
}


## no critic: 'ProhibitStringyEval'
eval q|
with qw(Orbital::CLI::Command::Role::Option::RepoPath);
|;

1;
