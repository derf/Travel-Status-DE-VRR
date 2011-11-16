#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use File::Slurp qw(slurp);
use Test::More tests => 96;

BEGIN {
	use_ok('Travel::Status::DE::VRR');
}
require_ok('Travel::Status::DE::VRR');

my $xml = slurp('t/in/essen_hb.xml');

my $status = Travel::Status::DE::VRR->new_from_xml(xml => $xml);

isa_ok($status, 'Travel::Status::DE::VRR');
can_ok($status, qw(errstr results));

my @results = $status->results;

for my $result (@results) {
	isa_ok($result, 'Travel::Status::DE::VRR::Result');
	can_ok($result, qw(date destination info line time type platform));
}

is($results[0]->destination, 'Düsseldorf Hbf', 'first result: destination ok');
is($results[0]->info, undef, 'first result: no info');
is($results[0]->line, 'ICE 946 Intercity-Express', 'first result: line ok');
is($results[0]->date, '16.11.2011', 'first result: date ok');
is($results[0]->time, '09:36', 'first result: time ok');
is($results[0]->platform, '#1', 'first result: platform ok');

is($results[-1]->destination, 'Essen Dellwig Bahnhof', 'last result: destination ok');
is($results[-1]->info, undef, 'last result: no info');
is($results[-1]->line, '166', 'last result: line ok');
is($results[-1]->date, '16.11.2011', 'last result: date ok');
is($results[-1]->time, '09:54', 'last result: time ok');
is($results[-1]->platform, '9', 'last result: platform ok');
