#!/usr/bin/env perl

use strict;
use warnings;
use Module::Build;

Module::Build->new(

	build_requires => {
		'Test::More' => 0,
		'Test::Pod' => 0,
	},
	module_name => 'Travel::Status::DE::VRR',
	license => 'unrestricted',
	requires => {
		'perl' => '5.10.1',
		'Getopt::Long' => 0,
		'XML::LibXML' => 0,
	},
	sign => 1,

)->create_build_script();
