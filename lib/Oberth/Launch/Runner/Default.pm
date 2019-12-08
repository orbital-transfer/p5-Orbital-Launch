use Modern::Perl;
package Oberth::Launch::Runner::Default;
# ABSTRACT: Default runner

use Mu;
use Oberth::Manoeuvre::Common::Setup;
use Capture::Tiny ();
use File::chdir;
use aliased 'Oberth::Launch::Runnable::Sudo';

use IO::Async::Loop;
use IO::Async::Function;
use IO::Async::Timer::Periodic;

use Oberth::Launch::System::Docker;

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
	my ( $env, $command, $pwd, $user_args ) = @_;

	use File::chdir;
	local $CWD = $pwd;
	local %ENV = %{ $env };

	local $( = $user_args->{group};
	local $) = $(;

	local $< = $user_args->{user};
	local $> = $<;

	my $exit = CORE::system( @{ $command } );
}

method _system_with_env_args( $runnable ) {
	my $env = $runnable->environment->environment_hash;
	my $user_args = { user => $> , group => $) };
	if( ! $runnable->admin_privilege && Oberth::Launch::System::Docker->is_inside_docker ) {
		# become a non-root user
		$user_args->{group} = '1000';
		$user_args->{user} = 1000;
		$env->{HOME} = '/home/notroot';
	}
	return (
		$env,
		$runnable->command,
		$CWD,
		$user_args,
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
