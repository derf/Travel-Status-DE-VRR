package Travel::Status::DE::VRR;

use strict;
use warnings;
use 5.010;

our $VERSION = '0.00';

use Carp qw(confess);
use Travel::Status::DE::VRR::Result;
use WWW::Mechanize;
use XML::LibXML;

sub new {
	my ( $class, %opt ) = @_;

	my $mech = WWW::Mechanize->new();
	my @now  = localtime( time() );

	if ( not( $opt{place} and $opt{name} ) ) {
		confess('You need to specify a place and a name');
	}
	if ( $opt{type} and not( $opt{type} ~~ [qw[stop address poi]] ) ) {
		confess('type must be stop, address or poi');
	}

	my $self = {
		post => {
			command                => q{},
			deleteAssignedStops_dm => '1',
			help                   => 'Hilfe',
			itdDateDay             => $now[3],
			itdDateMonth           => $now[4] + 1,
			itdDateYear            => $now[5] + 1900,
			itdLPxx_id_dm          => ':dm',
			itdLPxx_mapState_dm    => q{},
			itdLPxx_mdvMap2_dm     => q{},
			itdLPxx_mdvMap_dm      => '3406199:401077:NAV3',
			itdLPxx_transpCompany  => 'vrr',
			itdLPxx_view           => q{},
			itdTimeHour            => $now[2],
			itdTimeMinute          => $now[1],
			language               => 'de',
			nameInfo_dm            => 'invalid',
			nameState_dm           => 'empty',
			name_dm                => $opt{name},
			placeInfo_dm           => 'invalid',
			placeState_dm          => 'empty',
			place_dm               => $opt{place},
			ptOptionsActive        => '1',
			requestID              => '0',
			reset                  => 'neue Anfrage',
			sessionID              => '0',
			submitButton           => 'anfordern',
			typeInfo_dm            => 'invalid',
			type_dm                => $opt{type} // 'stop',
			useProxFootSearch      => '0',
			useRealtime            => '1',
		},
	};

	bless( $self, $class );

	$mech->post( 'http://efa.vrr.de/vrr/XSLT_DM_REQUEST', $self->{post} );

	if ( $mech->response->is_error ) {
		$self->{errstr} = $mech->response->status_line;
		return $self;
	}

	my $form = $mech->form_number(1);

	if ( not $form ) {
		$self->{errstr} = 'Unable to find the form - no lines returned?';
		return $self;
	}

	for my $input ( $form->find_input( 'dmLineSelection', 'option' ) ) {
		$input->check();
	}

	$mech->click('submitButton');

	if ( $mech->response->is_error ) {
		$self->{errstr} = $mech->response->status_line;
		return $self;
	}

	$self->{html} = $mech->response->decoded_content;

	$self->{tree} = XML::LibXML->load_html(
		string            => $self->{html},
		recover           => 2,
		suppress_errors   => 1,
		suppress_warnings => 1,
	);

	return $self;
}

sub new_from_html {
	my ( $class, %opt ) = @_;

	my $self = { html => $opt{html}, };

	$self->{tree} = XML::LibXML->load_html(
		string            => $self->{html},
		recover           => 2,
		suppress_errors   => 1,
		suppress_warnings => 1,
	);

	return bless( $self, $class );
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub results {
	my ($self) = @_;
	my @results;

	my $xp_element = XML::LibXML::XPathExpression->new(
		'//td[@colspan="3"]/table/tr[starts-with(@class,"bgColor")]');

	my @parts = (
		[ 'time',     './td[2]' ],
		[ 'platform', './td[3]' ],
		[ 'line',     './td[5]' ],
		[ 'dest',     './td[7]' ],
		[ 'info',     './td[9]' ],
	);

	@parts = map { [ $_->[0], XML::LibXML::XPathExpression->new( $_->[1] ) ] }
	  @parts;

	for my $tr ( $self->{tree}->findnodes($xp_element) ) {
		my ( $time, $platform, $line, $dest, $info )
		  = map { ( $tr->findnodes( $_->[1] ) )[0]->textContent } @parts;

		push(
			@results,
			Travel::Status::DE::VRR::Result->new(
				time        => $time,
				platform    => $platform,
				line        => $line,
				destination => $dest,
				info        => $info,
			)
		);
	}

	return @results;
}

1;

__END__

=head1 NAME

Travel::Status::DE::VRR - inofficial VRR departure monitor

=head1 SYNOPSIS

    use Travel::Status::DE::VRR;

    my $status = Travel::Status::DE::VRR->new(
        place => 'Essen', name => 'Helenenstr'
    );

    for my $d ($status->results) {
        printf(
            "%s %-8s %-5s %s\n",
            $d->time, $d->platform, $d->line, $d->destination
        );
    }

=head1 VERSION

version 0.00

=head1 DESCRIPTION

Travel::Status::DE::VRR is an inofficial interface to the VRR departure
monitor available at
L<http://efa.vrr.de/vrr/XSLT_DM_REQUEST?language=de&itdLPxx_transpCompany=vrr&>.

It reports all upcoming tram/bus/train departures at a given place.

=head1 METHODS

=over

=item my $status = Travel::Status::DE::VRR->new(I<%opt>)

Requests the departures as specified by I<opts> and returns a new
Travel::Status::DE::VRR object.  Dies if the wrong I<opts> were passed.

Arguments:

=over

=item B<place> => I<place>

Name of the place/city

=item B<type> => B<address>|B<poi>|B<stop>

Type of the following I<name>.  B<poi> means "point of interest".  Defaults to
B<stop> (stop/station name).

=item B<name> => I<name>

address / poi / stop name to list departures for.

=back

=item $status->errstr

In case of an error in the HTTP requests, returns a string describing it.  If
no error occured, returns undef.

=item $status->results

Returns a list of Travel::Status::DE::VRR::Result(3pm) objects, each one describing
one departure.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * WWW::Mechanize(3pm)

=item * XML::LibXML(3pm)

=back

=head1 BUGS AND LIMITATIONS

Not all features of the web interface are supported.

=head1 SEE ALSO

efa-m(1), Travel::Status::DE::VRR::Result(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
