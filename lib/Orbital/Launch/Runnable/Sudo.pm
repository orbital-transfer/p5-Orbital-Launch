use Modern::Perl;
package Orbital::Launch::Runnable::Sudo;
# ABSTRACT: Turn a Runnable into a sudo Runnable

use Mu;
use Orbital::Transfer::Common::Setup;
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
		# Password has not been entered in prior to this.
		warn "No sudo password entered in yet: $stderr";

		# Try to see if NOPASSWD is in output
		my $nopasswd = 0;
		my ($sudo_l_stdout, $sudo_l_exit);
		try {
			local $SIG{ALRM} = sub { die "alarm\n" };
			alarm 2;
			($sudo_l_stdout, undef, $sudo_l_exit) = capture {
				system(qw(sudo -l));
			};
			alarm 0;
		} catch {
			# Timed out.
			$nopasswd = 0;
			warn "Can not access sudo list without password";
		};

		$nopasswd = $sudo_l_stdout =~ m/\Q(ALL) NOPASSWD: ALL\E/s;

		return 1 if $nopasswd;
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
