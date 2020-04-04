#!/usr/bin/env perl

use Test::Most tests => 1;

use lib 't/lib';
use Oberth::Launch::Environment::Perl;
use Oberth::Launch::Runner::Default;

subtest "Test Perl environment" => sub {
	my $env = Oberth::Launch::Environment::Perl->new(
		perl => $^X,
		runner => Oberth::Launch::Runner::Default->new,
	);
	ok $env->sitebin_path;
};

done_testing;
