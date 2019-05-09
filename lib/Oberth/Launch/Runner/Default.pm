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
		code => \&_system_with_env,
	);
};

sub _system_with_env {
	my ( $env, $command ) = @_;

	local %ENV = %{ $env };
	my $exit = CORE::system( @{ $command } );
}

method _system_with_env_args( $runnable ) {
	return (
		$runnable->environment->environment_hash,
		$runnable->command,
	);
}

lazy timer => method() {
	my $timer = IO::Async::Timer::Periodic->new(
		interval => 60,

		on_tick => sub {
			print STDERR "SYSTEM KEEP-ALIVE.\n";
		},
	);
};

method _to_sudo($runnable) {
	if( $runnable->admin_privilege ) {
		if( ! Sudo->is_admin_user ) {
			if( Sudo->has_sudo_command
				&& Sudo->sudo_does_not_require_password ) {

				$runnable = Sudo->to_sudo_runnable( $runnable );
			} else {
				warn "Not running command (requires admin privilege): @{ $runnable->command }";
			}
		}
	}

	return $runnable;
}

method system_sync( $runnable, :$log = 1 ) {
	$runnable = $self->_to_sudo( $runnable );

	my $exit;

	say STDERR "Running command @{ $runnable->command }" if $log;
	$exit = _system_with_env( $self->_system_with_env_args(
		$runnable
	));

	if( $exit != 0 ) {
		die "Command '@{ $runnable->command }' exited with $exit";
	}

	return $exit;
}

method system( $runnable ) {
	$runnable = $self->_to_sudo( $runnable );

	my $loop = $self->loop;

	$self->timer->start;

	my $exit;

	say STDERR "Running command @{ $runnable->command }";
	$self->system_function->call(
		args => [ $self->_system_with_env_args( $runnable ) ],
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
	say STDERR "Running command @{ $runnable->command }";
	Capture::Tiny::capture(sub {
		$self->system_sync( $runnable, log => 0 );
	});
}

1;
