package Travel::Status::DE::VRR;

use strict;
use warnings;
use 5.010;

our $VERSION = '1.01';

use Carp qw(confess cluck);
use Encode qw(encode decode);
use Travel::Status::DE::VRR::Line;
use Travel::Status::DE::VRR::Result;
use LWP::UserAgent;
use XML::LibXML;

sub new {
	my ( $class, %opt ) = @_;

	my $ua  = LWP::UserAgent->new(%opt);
	my @now = localtime( time() );

	my @time = @now[ 2, 1 ];
	my @date = ( $now[3], $now[4] + 1, $now[5] + 1900 );

	if ( not( $opt{place} and $opt{name} ) ) {
		confess('You need to specify a place and a name');
	}
	if ( $opt{type} and not( $opt{type} ~~ [qw[stop address poi]] ) ) {
		confess('type must be stop, address or poi');
	}

	## no critic (RegularExpressions::ProhibitUnusedCapture)
	## no critic (Variables::ProhibitPunctuationVars)

	if (    $opt{time}
		and $opt{time} =~ m{ ^ (?<hour> \d\d? ) : (?<minute> \d\d ) $ }x )
	{
		@time = @+{qw{hour minute}};
	}
	elsif ( $opt{time} ) {
		confess('Invalid time specified');
	}

	if (
		    $opt{date}
		and $opt{date} =~ m{ ^ (?<day> \d\d? ) [.] (?<month> \d\d? ) [.]
			(?<year> \d{4} )? $ }x
	  )
	{
		if ( $+{year} ) {
			@date = @+{qw{day month year}};
		}
		else {
			@date[ 0, 1 ] = @+{qw{day month}};
		}
	}
	elsif ( $opt{date} ) {
		confess('Invalid date specified');
	}

	my $self = {
		post => {
			command                => q{},
			deleteAssignedStops_dm => '1',
			help                   => 'Hilfe',
			itdDateDay             => $date[0],
			itdDateMonth           => $date[1],
			itdDateYear            => $date[2],
			itdLPxx_id_dm          => ':dm',
			itdLPxx_mapState_dm    => q{},
			itdLPxx_mdvMap2_dm     => q{},
			itdLPxx_mdvMap_dm      => '3406199:401077:NAV3',
			itdLPxx_transpCompany  => 'vrr',
			itdLPxx_view           => q{},
			itdTimeHour            => $time[0],
			itdTimeMinute          => $time[1],
			language               => 'de',
			mode                   => 'direct',
			nameInfo_dm            => 'invalid',
			nameState_dm           => 'empty',
			name_dm                => $opt{name},
			outputFormat           => 'XML',
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

	$ua->env_proxy;

	my $response
	  = $ua->post( 'http://efa.vrr.de/vrr/XSLT_DM_REQUEST', $self->{post} );

	if ( $response->is_error ) {
		$self->{errstr} = $response->status_line;
		return $self;
	}

	$self->{xml} = $response->decoded_content;

	$self->{tree} = XML::LibXML->load_xml( string => $self->{xml}, );

	$self->check_for_ambiguous();

	return $self;
}

sub new_from_xml {
	my ( $class, %opt ) = @_;

	my $self = { xml => $opt{xml}, };

	$self->{tree} = XML::LibXML->load_xml( string => $self->{xml}, );

	return bless( $self, $class );
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub sprintf_date {
	my ($e) = @_;

	return sprintf( '%02d.%02d.%d',
		$e->getAttribute('day'),
		$e->getAttribute('month'),
		$e->getAttribute('year'),
	);
}

sub sprintf_time {
	my ($e) = @_;

	return sprintf( '%02d:%02d',
		$e->getAttribute('hour'),
		$e->getAttribute('minute'),
	);
}

sub check_for_ambiguous {
	my ($self) = @_;

	my $xml = $self->{tree};

	my $xp_place = XML::LibXML::XPathExpression->new('//itdOdv/itdOdvPlace');
	my $xp_name  = XML::LibXML::XPathExpression->new('//itdOdv/itdOdvName');
	my $xp_mesg
	  = XML::LibXML::XPathExpression->new('//itdMessage[@type="error"]');

	my $xp_place_elem = XML::LibXML::XPathExpression->new('./odvPlaceElem');
	my $xp_name_elem  = XML::LibXML::XPathExpression->new('./odvNameElem');

	my $e_place = ( $xml->findnodes($xp_place) )[0];
	my $e_name  = ( $xml->findnodes($xp_name) )[0];
	my @e_mesg  = $xml->findnodes($xp_mesg);

	if ( not( $e_place and $e_name ) ) {

		# this should not happen[tm]
		cluck('skipping ambiguity check- itdOdvPlace/itdOdvName missing');
		return;
	}

	my $s_place = $e_place->getAttribute('state');
	my $s_name  = $e_name->getAttribute('state');

	if ( $s_place eq 'list' ) {
		$self->{errstr} = sprintf(
			'Ambiguous place input: %s',
			join( q{ | },
				map { decode( 'UTF-8', $_->textContent ) }
				  @{ $e_place->findnodes($xp_place_elem) } )
		);
		return;
	}
	if ( $s_name eq 'list' ) {
		$self->{errstr} = sprintf(
			'Ambiguous name input: %s',
			join( q{ | },
				map { decode( 'UTF-8', $_->textContent ) }
				  @{ $e_name->findnodes($xp_name_elem) } )
		);
		return;
	}
	if ( $s_place eq 'notidentified' ) {
		$self->{errstr} = 'invalid place parameter';
		return;
	}
	if ( $s_name eq 'notidentified' ) {
		$self->{errstr} = 'invalid name parameter';
		return;
	}
	if (@e_mesg) {
		$self->{errstr} = join( q{; }, map { $_->textContent } @e_mesg );
		return;
	}

	return;
}

sub lines {
	my ($self) = @_;
	my @lines;

	my $xp_element
	  = XML::LibXML::XPathExpression->new('//itdServingLines/itdServingLine');

	my $xp_info  = XML::LibXML::XPathExpression->new('./itdNoTrain');
	my $xp_route = XML::LibXML::XPathExpression->new('./itdRouteDescText');
	my $xp_oper  = XML::LibXML::XPathExpression->new('./itdOperator/name');

	if ( $self->{lines} ) {
		return @{ $self->{lines} };
	}

	for my $e ( $self->{tree}->findnodes($xp_element) ) {

		my $e_info  = ( $e->findnodes($xp_info) )[0];
		my $e_route = ( $e->findnodes($xp_route) )[0];
		my $e_oper  = ( $e->findnodes($xp_oper) )[0];

		if ( not( $e_info and $e_oper ) ) {
			cluck( 'node with insufficient data. This should not happen. '
				  . $e->getAttribute('number') );
			next;
		}

		my $line       = $e->getAttribute('number');
		my $direction  = $e->getAttribute('direction');
		my $valid      = $e->getAttribute('valid');
		my $type       = $e_info->getAttribute('name');
		my $route      = ( $e_route ? $e_route->textContent : undef );
		my $operator   = $e_oper->textContent;
		my $identifier = $e->getAttribute('stateless');

		push(
			@lines,
			Travel::Status::DE::VRR::Line->new(
				name       => $line,
				direction  => decode( 'UTF-8', $direction ),
				valid      => $valid,
				type       => decode( 'UTF-8', $type ),
				route      => decode( 'UTF-8', $route ),
				operator   => decode( 'UTF-8', $operator ),
				identifier => $identifier,
			)
		);
	}

	$self->{lines} = \@lines;

	return @lines;
}

sub results {
	my ($self) = @_;
	my @results;

	my $xp_element = XML::LibXML::XPathExpression->new('//itdDeparture');

	my $xp_date  = XML::LibXML::XPathExpression->new('./itdDateTime/itdDate');
	my $xp_time  = XML::LibXML::XPathExpression->new('./itdDateTime/itdTime');
	my $xp_rdate = XML::LibXML::XPathExpression->new('./itdRTDateTime/itdDate');
	my $xp_rtime = XML::LibXML::XPathExpression->new('./itdRTDateTime/itdTime');
	my $xp_line  = XML::LibXML::XPathExpression->new('./itdServingLine');
	my $xp_info
	  = XML::LibXML::XPathExpression->new('./itdServingLine/itdNoTrain');

	if ( $self->{results} ) {
		return @{ $self->{results} };
	}

	$self->lines;

	for my $e ( $self->{tree}->findnodes($xp_element) ) {

		my $e_date = ( $e->findnodes($xp_date) )[0];
		my $e_time = ( $e->findnodes($xp_time) )[0];
		my $e_line = ( $e->findnodes($xp_line) )[0];
		my $e_info = ( $e->findnodes($xp_info) )[0];

		my $e_rdate = ( $e->findnodes($xp_rdate) )[0];
		my $e_rtime = ( $e->findnodes($xp_rtime) )[0];

		if ( not( $e_date and $e_time and $e_line ) ) {
			cluck('node with insufficient data. This should not happen');
			next;
		}

		my $date = sprintf_date($e_date);
		my $time = sprintf_time($e_time);

		my $rdate = $e_rdate ? sprintf_date($e_rdate) : $date;
		my $rtime = $e_rtime ? sprintf_time($e_rtime) : $time;

		my $platform  = $e->getAttribute('platform');
		my $line      = $e_line->getAttribute('number');
		my $dest      = $e_line->getAttribute('direction');
		my $info      = $e_info->textContent;
		my $countdown = $e->getAttribute('countdown');
		my $delay     = $e_info->getAttribute('delay') // 0;
		my $type      = $e_info->getAttribute('name');

		my $platform_is_db = 0;

		my @line_obj
		  = grep { $_->{identifier} eq $e_line->getAttribute('stateless') }
		  @{ $self->{lines} };

		if ( $platform =~ s{ ^ \# }{}ox ) {
			$platform_is_db = 1;
		}

		push(
			@results,
			Travel::Status::DE::VRR::Result->new(
				date        => $rdate,
				time        => $rtime,
				platform    => $platform,
				platform_db => $platform_is_db,
				lineref     => $line_obj[0] // undef,
				line        => $line,
				destination => decode( 'UTF-8', $dest ),
				countdown   => $countdown,
				info        => decode( 'UTF-8', $info ),
				delay       => $delay,
				sched_date  => $date,
				sched_time  => $time,
				type        => $type,
			)
		);
	}

	@results = map { $_->[0] }
	  sort { $a->[1] <=> $b->[1] }
	  map { [ $_, $_->countdown ] } @results;

	$self->{results} = \@results;

	return @results;
}

1;

__END__

=head1 NAME

Travel::Status::DE::VRR - unofficial VRR departure monitor

=head1 SYNOPSIS

    use Travel::Status::DE::VRR;

    my $status = Travel::Status::DE::VRR->new(
        place => 'Essen', name => 'Helenenstr'
    );

    for my $d ($status->results) {
        printf(
            "%s %d %-5s %s\n",
            $d->time, $d->platform, $d->line, $d->destination
        );
    }

=head1 VERSION

version 1.01

=head1 DESCRIPTION

Travel::Status::DE::VRR is an unofficial interface to the VRR departure
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

In case of en HTTP request or EFA error, returns a string describing it. If
none occured, returns undef.

=item $status->lines

Returns a list of Travel::Status::DE::VRR::Line(3pm) objects, each one
describing one line servicing the selected station.

=item $status->results

Returns a list of Travel::Status::DE::VRR::Result(3pm) objects, each one describing
one departure.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * LWP::UserAgent(3pm)

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
