#!/usr/bin/env perl

use Test::Most;

use Oberth::Launch::PackageManager::APT;
use Oberth::Launch::Runner::Default;
use Oberth::Launch::RepoPackage::APT;
use aliased 'Oberth::Launch::Runnable';

if( ! Oberth::Launch::PackageManager::APT->loadable ) {
	plan skip_all => 'Test needs Debian system';
} else {
	plan tests => 2;
};

sub init {
	my $runner = Oberth::Launch::Runner::Default->new;
	my $apt = Oberth::Launch::PackageManager::APT->new( runner => $runner );

	($runner, $apt);
}

subtest "dpkg package" => sub {
	my ($runner, $apt) = init;

	my $package = Oberth::Launch::RepoPackage::APT->new( name => 'dpkg' );
	my $version = $apt->installed_version( $package );

	my ($expected_version) = $runner->capture( Runnable->new(
		command => [ qw(dpkg --version) ]
	) ) =~ /program version (\S+)/m;

	is $version, $expected_version, 'correct version';

	my @versions = $apt->installable_versions( $package );
	ok grep { $_ eq $expected_version } @versions, 'dpkg is up to date with installable versions';
};

subtest "Non-existent package" => sub {
	my ($runner, $apt) = init;

	my $package = Oberth::Launch::RepoPackage::APT->new( name => 'not-a-real-package' );
	throws_ok { $apt->installed_version( $package ) } qr/no packages found/;

	throws_ok { $apt->installable_versions( $package ) } qr/Unable to locate package/;
};

done_testing;
