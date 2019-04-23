use Modern::Perl;
package Oberth::Launch::Runner::Default;
# ABSTRACT: Default runner

use Mu;
use Oberth::Manoeuvre::Common::Setup;
use IPC::System::Simple ();
use Capture::Tiny ();
use aliased 'Oberth::Launch::Runnable::Sudo';

method system( $runnable ) {
	if( $runnable->admin_privilege ) {
		if( ! Sudo->is_admin_user ) {
			if( Sudo->has_sudo_command
				&& Sudo->sudo_does_not_require_password ) {

				$runnable = Sudo->to_sudo_runnable( $runnable );

			} else {
				warn "Not running command (requires admin privilege): @{ $runnable->command }";
				return;
			}
		}
	}

	local %ENV = %{ $runnable->environment->environment_hash };
	use autodie qw(:system);
	system( @{ $runnable->command } );
}

method capture( $runnable ) {
	Capture::Tiny::capture(sub {
		$self->system( $runnable );
	})
}

1;
