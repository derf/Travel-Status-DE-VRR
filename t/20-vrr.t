#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use File::Slurp qw(slurp);
use Test::More tests => 94;

BEGIN {
	use_ok('Travel::Status::DE::VRR');
}
require_ok('Travel::Status::DE::VRR');

my $html = slurp('t/in/essen_bp.html');

my $status = Travel::Status::DE::VRR->new_from_html(html => $html);

isa_ok($status, 'Travel::Status::DE::VRR');
can_ok($status, qw(errstr results));

my @results = $status->results;

for my $result (@results) {
	isa_ok($result, 'Travel::Status::DE::VRR::Result');
	can_ok($result, qw(destination info line time platform));
}

is($results[0]->destination, 'Essen Wertstr.', 'first result: destination ok');
is($results[0]->info, q{}, 'first result: no info');
is($results[0]->line, '103', 'first result: line ok');
is($results[0]->time, '20:19', 'first result: time ok');
is($results[0]->platform, 'Bstg. 1', 'first result: platform ok');

is($results[-1]->destination, 'Essen Germaniaplatz', 'last result: destination ok');
is($results[-1]->info, q{}, 'last result: no info');
is($results[-1]->line, '101', 'last result: line ok');
is($results[-1]->time, '21:07', 'last result: time ok');
is($results[-1]->platform, 'Bstg. 1', 'last result: platform ok');
