#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use utf8;

use File::Slurp qw(slurp);
use Test::More tests => 7;

BEGIN {
	use_ok('Travel::Status::DE::VRR');
}
require_ok('Travel::Status::DE::VRR');

my $xml = slurp('t/in/essen_alfredusbad_ambiguous.xml');

my $status = Travel::Status::DE::VRR->new_from_xml(xml => $xml);

isa_ok($status, 'Travel::Status::DE::VRR');
can_ok($status, qw(errstr results));

$status->check_for_ambiguous();

is($status->errstr, 'Ambiguous name input: Alfredusbad | Am Alfredusbad',
	'errstr ok');

is_deeply([$status->lines], [], 'no lines');
is_deeply([$status->results], [], 'no results');
