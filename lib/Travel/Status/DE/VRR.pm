package Travel::Status::DE::VRR;

use strict;
use warnings;
use 5.010;

our $VERSION = '0.00';

use Travel::Status::DE::VRR::Result;
use WWW::Mechanize;
use XML::LibXML;

sub new {
	my ( $class, %opt ) = @_;

	my $mech = WWW::Mechanize->new();
	my @now = localtime( time() );

	my $self = {
		post => {
			command => q{},
			deleteAssignedStops_dm => '1',
			help => 'Hilfe',
			itdDateDay => $now[3],
			itdDateMonth => $now[4] + 1,
			itdDateYear => $now[5] + 1900,
			itdLPxx_id_dm => ':dm',
			itdLPxx_mapState_dm => q{},
			itdLPxx_mdvMap2_dm => q{},
			itdLPxx_mdvMap_dm => '3406199:401077:NAV3',
			itdLPxx_transpCompany => 'vrr',
			itdLPxx_view => q{},
			itdTimeHour => $now[2],
			itdTimeMinute => $now[1],
			language => 'de',
			nameInfo_dm => 'invalid',
			nameState_dm => 'empty',
			name_dm => $opt{name},
			placeInfo_dm => 'invalid',
			placeState_dm => 'empty',
			place_dm => $opt{place},
			ptOptionsActive => '1',
			requestID => '0',
			reset => 'neue Anfrage',
			sessionID => '0',
			submitButton => 'anfordern',
			typeInfo_dm => 'invalid',
			type_dm => 'stop',
			useProxFootSearch => '0',
			useRealtime => '1',
		},
	};

	$mech->post( 'http://efa.vrr.de/vrr/XSLT_DM_REQUEST', $self->{post} );

	if ( $mech->response->is_error ) {
		die( $mech->response->status_line );
	}

	my $form = $mech->form_number(1);

	for my $input ( $form->find_input( 'dmLineSelection', 'option' ) ) {
		$input->check();
	}

	$mech->click('submitButton');

	if ( $mech->response->is_error ) {
		die( $mech->response->status_line );
	}

	$self->{html} = $mech->response->decoded_content;

	$self->{tree} = XML::LibXML->load_html(
		string => $self->{html},
		recover => 2,
		suppress_errors => 1,
		suppress_warnings => 1,
	);

	return bless( $self, $class );
}

sub results {
	my ($self) = @_;
	my @results;

	my $xp_element = XML::LibXML::XPathExpression->new(
		'//td[@colspan="3"]/table/tr[starts-with(@class,"bgColor")]');

	my @parts = (
		['time', './td[2]'],
		['platform', './td[3]'],
		['line', './td[5]'],
		['dest', './td[7]'],
	);

	@parts = map { [ $_->[0], XML::LibXML::XPathExpression->new($_->[1]) ] }
	@parts;

	for my $tr ($self->{tree}->findnodes($xp_element) ) {
		my ($time, $platform, $line, $dest) = map { ($tr->findnodes($_->[1]))[0]->textContent } @parts;
		push(@results, Travel::Status::DE::VRR::Result->new(
			time => $time,
			platform => $platform,
			line => $line,
			destination => $dest,
		));
	}

	return @results;
}

1;

__END__

=head1 NAME

Travel::Status::DE::VRR - inofficial VRR departure monitor

=head1 SYNOPSIS

=head1 VERSION

version

=head1 DESCRIPTION

=head1 METHODS

=over

=back

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over

=back

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
