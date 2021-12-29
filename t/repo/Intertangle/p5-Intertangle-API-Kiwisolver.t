#!/usr/bin/env perl

use Test::Most tests => 1;

use lib 't/lib';

use TestRepo;

TestRepo->test_github("Intertangle/p5-Intertangle-API-Kiwisolver");

done_testing;
