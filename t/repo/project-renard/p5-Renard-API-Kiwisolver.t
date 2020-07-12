#!/usr/bin/env perl

use Test::Most tests => 1;

use lib 't/lib';

use TestRepo;

TestRepo->test_github("project-renard/p5-Renard-API-Kiwisolver");

done_testing;
