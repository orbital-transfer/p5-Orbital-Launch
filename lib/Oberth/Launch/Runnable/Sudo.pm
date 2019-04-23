use Modern::Perl;
package Oberth::Launch::Runnable::Sudo;
# ABSTRACT: Turn a Runnable into a sudo Runnable

use Mu;
use Oberth::Manoeuvre::Common::Setup;
use File::Which;
use Clone qw(clone);
use Capture::Tiny qw(capture);

classmethod is_admin_user() {
	$> == 0;
}

classmethod has_sudo_command() {
	return !! which('sudo');
}

classmethod sudo_does_not_require_password() {
	# See <https://superuser.com/questions/553932/how-to-check-if-i-have-sudo-access/1281228#1281228>.
	# NOTE If we do not have sudo, it might be possible to use `su -c`, but
	# only if we set up a way to act interactively.
	my ($stdout, $stderr, $exit) = capture {
		system(qw(sudo -nv));
	};
	if( 0 != $exit && $stderr =~ /^sudo:/ ) {
		warn "$stderr";
	}
	return 0 == $exit;
}

classmethod to_sudo_runnable( $runnable ) {
	return $runnable->cset(
		command => [ 'sudo', @{ clone($runnable->command) } ],
		admin_privilege => 0,
	);
}

1;
