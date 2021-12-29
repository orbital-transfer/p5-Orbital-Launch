#!/usr/bin/env perl

use Test::Most;

plan exists $INC{'Devel/Cover.pm'}
	? ( skip_all => 'Skipping under Devel::Cover' )
	: ( tests => 1 );

use lib 't/lib';

use TestRepo;

TestRepo->test_github("Intertangle/p5-Intertangle-Yarn");

done_testing;
