#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use Encode qw(decode);
use File::Slurp qw(slurp);
use Test::More tests => 102;

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

is($results[0]->destination, decode('UTF-8', 'Düsseldorf Hbf'), 'first result: destination ok');
is($results[0]->info, 'Bordrestaurant', 'first result: no info');
is($results[0]->line, 'ICE 946 Intercity-Express', 'first result: line ok');
is($results[0]->date, '16.11.2011', 'first result: real date ok');
is($results[0]->time, '09:40', 'first result: real time ok');
is($results[0]->delay, 4, 'first result: delay 4');
is($results[0]->sched_date, '16.11.2011', 'first result: scheduled date ok');
is($results[0]->sched_time, '09:36', 'first result: scheduled time ok');
is($results[0]->platform, '#1', 'first result: platform ok');

is($results[-1]->destination, 'Essen Dellwig Bahnhof', 'last result: destination ok');
is($results[-1]->info, q{}, 'last result: no info');
is($results[-1]->delay, 0, 'lest result: no delay');
is($results[-1]->line, '166', 'last result: line ok');
is($results[-1]->date, '16.11.2011', 'last result: date ok');
is($results[-1]->time, '09:54', 'last result: time ok');
is($results[-1]->sched_date, '16.11.2011', 'first result: scheduled date ok');
is($results[-1]->sched_time, '09:54', 'first result: scheduled time ok');
is($results[-1]->platform, '9', 'last result: platform ok');
