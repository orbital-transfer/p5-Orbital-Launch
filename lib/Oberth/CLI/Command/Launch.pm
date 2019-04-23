use Oberth::Manoeuvre::Common::Setup;
package Oberth::CLI::Command::Launch;
# ABSTRACT: Launch commands

use Moo;
use CLI::Osprey;

method run() {
	require Oberth::Launch;
	Oberth::Launch->new_with_options->run;
}

1;
