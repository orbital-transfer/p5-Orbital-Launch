#!/usr/bin/env perl

use Test::Most tests => 1;

use lib 't/lib';
use Orbital::Launch::Environment::Perl;
use Orbital::Launch::Runner::Default;

subtest "Test Perl environment" => sub {
	my $env = Orbital::Launch::Environment::Perl->new(
		perl => $^X,
		runner => Orbital::Launch::Runner::Default->new,
	);
	ok $env->sitebin_path;
};

done_testing;
