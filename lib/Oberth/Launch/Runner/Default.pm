use Modern::Perl;
package Oberth::Launch::Runner::Default;
# ABSTRACT: Default runner

use Mu;
use Oberth::Manoeuvre::Common::Setup;
use Capture::Tiny ();
use aliased 'Oberth::Launch::Runnable::Sudo';

use IO::Async::Loop;
use IO::Async::Function;
use IO::Async::Timer::Periodic;

lazy loop => method() {
	my $loop = IO::Async::Loop->new;

	$loop->add( $self->system_function );

	$loop->add( $self->timer );

	$loop;
};

lazy system_function => method() {
	my $function = IO::Async::Function->new(
		code => sub {
			my ( $env, $command ) = @_;

			local %ENV = %{ $env };
			my $exit = CORE::system( @{ $command } );
		},
	);
};

lazy timer => method() {
	my $timer = IO::Async::Timer::Periodic->new(
		interval => 60,

		on_tick => sub {
			print STDERR "SYSTEM KEEP-ALIVE.\n";
		},
	);
};

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

	my $loop = $self->loop;

	$self->timer->start;

	my $exit;

	say STDERR "Running command @{ $runnable->command }";
	$self->system_function->call(
		args => [
			$runnable->environment->environment_hash,
			$runnable->command,
		],
		on_return => sub { $exit = shift },
		on_error => sub { },
	);

	$loop->loop_once while ! defined $exit;

	$self->timer->stop;

	if( $exit != 0 ) {
		die "Command '@{ $runnable->command }' exited with $exit";
	}

	return $exit;
}

method capture( $runnable ) {
	Capture::Tiny::capture(sub {
		$self->system( $runnable );
	})
}

1;
