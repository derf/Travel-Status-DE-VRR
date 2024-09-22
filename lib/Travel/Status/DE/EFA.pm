package Travel::Status::DE::EFA;

use strict;
use warnings;
use 5.010;
use utf8;

our $VERSION = '2.02';

use Carp qw(confess cluck);
use DateTime;
use DateTime::Format::Strptime;
use Encode qw(encode);
use JSON;
use Travel::Status::DE::EFA::Line;
use Travel::Status::DE::EFA::Departure;
use Travel::Status::DE::EFA::Stop;
use LWP::UserAgent;

my %efa_instance = (
	BSVG => {
		url  => 'https://bsvg.efa.de/bsvagstd',
		name => 'Braunschweiger Verkehrs-GmbH',
	},
	DING => {
		url     => 'https://www.ding.eu/ding3',
		stopseq =>
'https://www.ding.eu/ding3/XML_STOPSEQCOORD_REQUEST?=&jsonp=jsonpFn5&line=din:87002: :R:j24&stop=9001008&tripCode=290&date=20240520&time=14.0041.00&coordOutputFormat=WGS84[DD.DDDDD]&coordListOutputFormat=string&outputFormat=json&tStOTType=NEXT&hideBannerInfo=1',
		name => 'Donau-Iller Nahverkehrsverbund',
	},
	KVV => {
		url  => 'https://projekte.kvv-efa.de/sl3-alone',
		name => 'Karlsruher Verkehrsverbund',
	},
	LinzAG => {
		url      => 'https://www.linzag.at/static',
		name     => 'Linz AG',
		encoding => 'iso-8859-15',
	},
	MVV => {
		url  => 'https://efa.mvv-muenchen.de/mobile',
		name => 'Münchner Verkehrs- und Tarifverbund',
	},
	NVBW => {
		url  => 'https://www.efa-bw.de/nvbw',
		name => 'Nahverkehrsgesellschaft Baden-Württemberg',
	},
	VAG => {
		url  => 'https://efa.vagfr.de/vagfr3',
		name => 'Freiburger Verkehrs AG',
	},
	VGN => {
		url  => 'https://efa.vgn.de/vgnExt_oeffi',
		name => 'Verkehrsverbund Grossraum Nuernberg',
	},

	# HTTPS: certificate verification fails
	VMV => {
		url  => 'http://efa.vmv-mbh.de/vmv',
		name => 'Verkehrsgesellschaft Mecklenburg-Vorpommern',
	},
	VRN => {
		url  => 'https://www.vrn.de/mngvrn/',
		name => 'Verkehrsverbund Rhein-Neckar',
	},
	VRR => {
		url  => 'https://efa.vrr.de/vrr',
		name => 'Verkehrsverbund Rhein-Ruhr',
	},
	VRR2 => {
		url  => 'https://app.vrr.de/standard',
		name => 'Verkehrsverbund Rhein-Ruhr (alternative)',
	},
	VRR3 => {
		url  => 'https://efa.vrr.de/rbgstd3',
		name => 'Verkehrsverbund Rhein-Ruhr (alternative alternative)',
	},
	VVO => {
		url  => 'https://efa.vvo-online.de/VMSSL3',
		name => 'Verkehrsverbund Oberelbe',
	},
	VVS => {
		url  => 'https://www2.vvs.de/vvs',
		name => 'Verkehrsverbund Stuttgart',
	},

);

sub new_p {
	my ( $class, %opt ) = @_;
	my $promise = $opt{promise}->new;

	my $self;

	eval { $self = $class->new( %opt, async => 1 ); };
	if ($@) {
		return $promise->reject($@);
	}

	$self->{promise} = $opt{promise};

	$self->{ua}->post_p( $self->{efa_url} => form => $self->{post} )->then(
		sub {
			my ($tx) = @_;
			if ( my $err = $tx->error ) {
				$promise->reject(
"POST $self->{efa_url} returned HTTP $err->{code} $err->{message}"
				);
				return;
			}
			my $content = $tx->res->body;

			$self->{response} = $self->{json}->decode($content);

			if ( $self->{developer_mode} ) {
				say $self->{json}->pretty->encode( $self->{response} );
			}

			$self->check_for_ambiguous();

			if ( $self->{errstr} ) {
				$promise->reject( $self->{errstr} );
				return;
			}

			$promise->resolve($self);
			return;
		}
	)->catch(
		sub {
			my ($err) = @_;
			$promise->reject($err);
			return;
		}
	)->wait;

	return $promise;
}

sub new {
	my ( $class, %opt ) = @_;

	$opt{timeout} //= 10;
	if ( $opt{timeout} <= 0 ) {
		delete $opt{timeout};
	}

	if ( not( $opt{name} or $opt{from_json} ) ) {
		confess('You must specify a name');
	}
	if ( $opt{type}
		and not( $opt{type} =~ m{ ^ (?: stop stopID address poi ) $ }x ) )
	{
		confess('type must be stop, stopID, address, or poi');
	}

	if ( $opt{service} and exists $efa_instance{ $opt{service} } ) {
		$opt{efa_url} = $efa_instance{ $opt{service} }{url};
		if ( $opt{journey} ) {
			$opt{efa_url} .= '/XML_STOPSEQCOORD_REQUEST';
		}
		else {
			$opt{efa_url} .= '/XML_DM_REQUEST';
		}
		$opt{time_zone} //= $efa_instance{ $opt{service} }{time_zone};
	}

	if ( not $opt{efa_url} ) {
		confess('service or efa_url must be specified');
	}
	my $dt = $opt{datetime}
	  // DateTime->now( time_zone => $opt{time_zone} // 'Europe/Berlin' );

	## no critic (RegularExpressions::ProhibitUnusedCapture)
	## no critic (Variables::ProhibitPunctuationVars)

	if (    $opt{time}
		and $opt{time} =~ m{ ^ (?<hour> \d\d? ) : (?<minute> \d\d ) $ }x )
	{
		$dt->set(
			hour   => $+{hour},
			minute => $+{minute}
		);
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
			$dt->set(
				day   => $+{day},
				month => $+{month},
				year  => $+{year}
			);
		}
		else {
			$dt->set(
				day   => $+{day},
				month => $+{month}
			);
		}
	}
	elsif ( $opt{date} ) {
		confess('Invalid date specified');
	}

	my $self = {
		post => {
			language          => 'de',
			mode              => 'direct',
			outputFormat      => 'JSON',
			type_dm           => $opt{type} // 'stop',
			useProxFootSearch => $opt{proximity_search} ? '1' : '0',
			useRealtime       => '1',
			itdDateDay        => $dt->day,
			itdDateMonth      => $dt->month,
			itdDateYear       => $dt->year,
			itdTimeHour       => $dt->hour,
			itdTimeMinute     => $dt->minute,
			name_dm           => encode( 'UTF-8', $opt{name} ),
		},
		response       => $opt{from_json},
		developer_mode => $opt{developer_mode},
		efa_url        => $opt{efa_url},
		service        => $opt{service},
		strp_stopseq   => DateTime::Format::Strptime->new(
			pattern   => '%Y%m%d %H:%M',
			time_zone => 'Europe/Berlin',
		),
		strp_stopseq_s => DateTime::Format::Strptime->new(
			pattern   => '%Y%m%d %H:%M:%S',
			time_zone => 'Europe/Berlin',
		),

		json => JSON->new->utf8,
	};

	if ( $opt{place} ) {
		$self->{post}{placeInfo_dm}  = 'invalid';
		$self->{post}{placeState_dm} = 'empty';
		$self->{post}{place_dm}      = encode( 'UTF-8', $opt{place} );
	}

	if ( $opt{full_routes} ) {
		$self->{post}->{depType}                = 'stopEvents';
		$self->{post}->{includeCompleteStopSeq} = 1;
		$self->{want_full_routes}               = 1;
	}

	bless( $self, $class );

	if ( $opt{user_agent} ) {
		$self->{ua} = $opt{user_agent};
	}
	else {
		my %lwp_options = %{ $opt{lwp_options} // { timeout => 10 } };
		$self->{ua} = LWP::UserAgent->new(%lwp_options);
		$self->{ua}->env_proxy;
	}

	if ( $opt{async} ) {
		return $self;
	}

	if ( $self->{developer_mode} ) {
		say 'POST ' . $self->{efa_url};
		while ( my ( $key, $value ) = each %{ $self->{post} } ) {
			printf( "%30s = %s\n", $key, $value );
		}
	}

	if ( not $self->{response} ) {
		my $response = $self->{ua}->post( $self->{efa_url}, $self->{post} );

		if ( $response->is_error ) {
			$self->{errstr} = $response->status_line;
			return $self;
		}

		$self->{response} = $self->{json}->decode( $response->content );
	}

	if ( $self->{developer_mode} ) {
		say $self->{json}->pretty->encode( $self->{response} );
	}

	$self->check_for_ambiguous();

	return $self;
}

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub name_candidates {
	my ($self) = @_;

	if ( $self->{name_candidates} ) {
		return @{ $self->{name_candidates} };
	}
	return;
}

sub place_candidates {
	my ($self) = @_;

	if ( $self->{place_candidates} ) {
		return @{ $self->{place_candidates} };
	}
	return;
}

sub check_for_ambiguous {
	my ($self) = @_;

	my $json = $self->{response};

	if ( $json->{departureList} ) {
		return;
	}

	for my $m ( @{ $json->{dm}{message} // [] } ) {
		if ( $m->{name} eq 'error' and $m->{value} eq 'name list' ) {
			$self->{errstr} = "ambiguous name parameter";
			$self->{name_candidates}
			  = [ map { $_->{name} } @{ $json->{dm}{points} // [] } ];
			return;
		}
		if ( $m->{name} eq 'error' and $m->{value} eq 'place list' ) {
			$self->{errstr} = "ambiguous name parameter";
			$self->{name_candidates}
			  = [ map { $_->{name} } @{ $json->{dm}{points} // [] } ];
			return;
		}
	}

	return;
}

sub stop_name {
	my ($self) = @_;

	return $self->{response}{dm}{points}{point}{name};
}

sub stops {
	my ($self) = @_;

	if ( $self->{stops} ) {
		return @{ $self->{stops} };
	}

	my @stops;
	for my $stop ( @{ $self->{response}{dm}{itdOdvAssignedStops} // [] } ) {
		push(
			@stops,
			Travel::Status::DE::EFA::Stop->new(
				place     => $stop->{place},
				name      => $stop->{name},
				full_name => $stop->{nameWithPlace},
			)
		);
	}

	$self->{stops} = \@stops;
	return @stops;
}

sub lines {
	my ($self) = @_;

	if ( $self->{lines} ) {
		return @{ $self->{lines} };
	}

	for my $line ( @{ $self->{response}{servingLines}{lines} // [] } ) {
		push( @{ $self->{lines} }, $self->parse_line($line) );
	}

	return @{ $self->{lines} // [] };
}

sub parse_line {
	my ( $self, $line ) = @_;

	my $mode = $line->{mode} // {};

	return Travel::Status::DE::EFA::Line->new(
		type       => $mode->{product},
		name       => $mode->{name},
		number     => $mode->{number},
		direction  => $mode->{destination},
		valid      => $mode->{timetablePeriod},
		mot        => $mode->{product},
		operator   => $mode->{diva}{operator},
		identifier => $mode->{diva}{globalId},
		,
	);
}

sub parse_route {
	my ( $self, $stop_seq, $requested_id ) = @_;
	my @ret;

	if ( not $stop_seq ) {
		return \@ret;
	}

	# Oh EFA, you so silly
	if ( ref($stop_seq) eq 'HASH' ) {

		# For lines that start or terminate at the requested stop, onwardStopSeq / prevStopSeq includes the requested stop.
		if ( $stop_seq->{ref}{id} eq $requested_id ) {
			return \@ret;
		}
		$stop_seq = [$stop_seq];
	}

	for my $stop ( @{ $stop_seq // [] } ) {
		my $ref = $stop->{ref};
		my ( $arr, $dep );

		if ( $ref->{arrDateTimeSec} ) {
			$arr = $self->{strp_stopseq_s}
			  ->parse_datetime( $ref->{arrDateTimeSec} );
		}
		elsif ( $ref->{arrDateTime} ) {
			$arr = $self->{strp_stopseq}->parse_datetime( $ref->{arrDateTime} );
		}

		if ( $ref->{depDateTimeSec} ) {
			$dep = $self->{strp_stopseq_s}
			  ->parse_datetime( $ref->{depDateTimeSec} );
		}
		elsif ( $ref->{depDateTime} ) {
			$dep = $self->{strp_stopseq}->parse_datetime( $ref->{depDateTime} );
		}

		push(
			@ret,
			Travel::Status::DE::EFA::Stop->new(
				arr       => $arr,
				dep       => $dep,
				full_name => $stop->{name},
				place     => $stop->{place},
				name      => $stop->{nameWO},
				platform  => $ref->{platform} || $stop->{platformName} || undef,
			)
		);
	}

	return \@ret;
}

sub parse_departure {
	my ( $self, $departure ) = @_;

	my ( $sched_dt,   $real_dt );
	my ( $prev_route, $next_route );

	if ( my $dt = $departure->{dateTime} ) {
		$sched_dt = DateTime->new(
			year      => $dt->{year},
			month     => $dt->{month},
			day       => $dt->{day},
			hour      => $dt->{hour},
			minute    => $dt->{minute},
			second    => $dt->{second} // 0,
			time_zone => 'Europe/Berlin',
		);
	}

	if ( my $dt = $departure->{realDateTime} ) {
		$real_dt = DateTime->new(
			year      => $dt->{year},
			month     => $dt->{month},
			day       => $dt->{day},
			hour      => $dt->{hour},
			minute    => $dt->{minute},
			second    => $dt->{second} // 0,
			time_zone => 'Europe/Berlin',
		);
	}

	if ( $departure->{prevStopSeq} ) {
		$prev_route = $self->parse_route( $departure->{prevStopSeq},
			$departure->{stopID} );
	}
	if ( $departure->{onwardStopSeq} ) {
		$next_route = $self->parse_route( $departure->{onwardStopSeq},
			$departure->{stopID} );
	}

	my @hints
	  = map { $_->{content} } @{ $departure->{servingLine}{hints} // [] };

	return Travel::Status::DE::EFA::Departure->new(
		rt_datetime    => $real_dt,
		platform       => $departure->{platform},
		platform_name  => $departure->{platformName},
		platform_type  => $departure->{pointType},
		line           => $departure->{servingLine}{symbol},
		train_type     => $departure->{servingLine}{trainType},
		train_name     => $departure->{servingLine}{trainName},
		train_no       => $departure->{servingLine}{trainNum},
		origin         => $departure->{servingLine}{directionFrom},
		destination    => $departure->{servingLine}{direction},
		occupancy      => $departure->{occupancy},
		countdown      => $departure->{countdown},
		delay          => $departure->{servingLine}{delay},
		sched_datetime => $sched_dt,
		type           => $departure->{servingLine}{name},
		mot            => $departure->{servingLine}{motType},
		hints          => \@hints,
		prev_route     => $prev_route,
		next_route     => $next_route,
	);
}

sub results {
	my ($self) = @_;
	my @results;

	if ( $self->{results} ) {
		return @{ $self->{results} };
	}

	my $json = $self->{response};

	for my $departure ( @{ $json->{departureList} // [] } ) {
		push( @results, $self->parse_departure($departure) );
	}

	@results = map { $_->[0] }
	  sort { $a->[1] <=> $b->[1] }
	  map { [ $_, $_->countdown ] } @results;

	$self->{results} = \@results;

	return @results;
}

# static
sub get_efa_urls {
	return map {
		{ %{ $efa_instance{$_} }, shortname => $_ }
	} sort keys %efa_instance;
}

sub get_service {
	my ($service) = @_;
	return $efa_instance{$service};
}

1;

__END__

=head1 NAME

Travel::Status::DE::EFA - unofficial EFA departure monitor

=head1 SYNOPSIS

    use Travel::Status::DE::EFA;

    my $status = Travel::Status::DE::EFA->new(
        service => 'VRR',
        name => 'Essen Helenenstr'
    );

    for my $d ($status->results) {
        printf(
            "%s %-8s %-5s %s\n",
            $d->datetime->strftime('%H:%M'),
            $d->platform_name, $d->line, $d->destination
        );
    }

=head1 VERSION

version 2.02

=head1 DESCRIPTION

Travel::Status::DE::EFA is an unofficial interface to EFA-based departure
monitors.

It reports all upcoming tram/bus/train departures at a given place.

=head1 METHODS

=over

=item my $status = Travel::Status::DE::EFA->new(I<%opt>)

Requests the departures as specified by I<opts> and returns a new
Travel::Status::DE::EFA object.  B<service> and B<name> are
mandatory.  Dies if the wrong I<opts> were passed.

Arguments:

=over

=item B<service> => I<name>

EFA service. See C<< efa-m --list >> for known services.
If you found a service not listed there, please notify
E<lt>derf+efa@finalrewind.orgE<gt>.

=item B<place> => I<place>

Name of the place/city

=item B<type> => B<address>|B<poi>|B<stop>|B<stopID>

Type of the following I<name>.  B<poi> means "point of interest".  Defaults to
B<stop> (stop/station name).

=item B<name> => I<name>

address / poi / stop name to list departures for.

=item B<datetime> => I<DateTime object>

Request departures for the date/time specified by I<DateTime object>.
Default: now.

=item B<efa_encoding> => I<encoding>

Some EFA servers do not correctly specify their response encoding. If you
observe encoding issues, you can manually specify it here. Example:
iso-8859-15.

=item B<full_routes> => B<0>|B<1>

If true: Request full routes for all departures from the backend. This
enables the B<route_pre>, B<route_post> and B<route_interesting> accessors in
Travel::Status::DE::EFA::Departure(3pm).

=item B<proximity_search> => B<0>|B<1>

If true: Show departures for stops in the proximity of the requested place
as well.

=item B<timeout> => I<seconds>

Request timeout, the argument is passed on to LWP::UserAgent(3pm).
Default: 10 seconds. Set to 0 or a negative value to disable it.

=back

=item my $status_p = Travel::Status::DE::EFA->new_p(I<%opt>)

Returns a promise that resolves into a Travel::Status::DE::EFA instance
($status) on success and rejects with an error message on failure. In addition
to the arguments of B<new>, the following mandatory arguments must be set.

=over

=item B<promise> => I<promises module>

Promises implementation to use for internal promises as well as B<new_p> return
value. Recommended: Mojo::Promise(3pm).

=item B<user_agent> => I<user agent>

User agent instance to use for asynchronous requests. The object must implement
a B<post_p> function. Recommended: Mojo::UserAgent(3pm).

=back

=item $status->errstr

In case of an HTTP request or EFA error, returns a string describing it. If
none occured, returns undef.

=item $status->identified_data

Returns a list of the identified values for I<place> and I<name>.
For instance, when requesting data for "E", "MartinSTR", B<identified_data>
will return ("Essen", "Martinstr.").

=item $status->lines

Returns a list of Travel::Status::DE::EFA::Line(3pm) objects, each one
describing one line servicing the selected station.

=item $status->name_candidates

Returns a list of B<name> candidates if I<name> is ambiguous. Returns
nothing (undef / empty list) otherwise.

=item $status->place_candidates

Returns a list of B<place> candidates if I<place> is ambiguous. Returns
nothing (undef / empty list) otherwise.

=item $status->results

Returns a list of Travel::Status::DE::EFA::Departure(3pm) objects, each one describing
one departure.

=item Travel::Status::DE::EFA::get_efa_urls()

Returns a list of known EFA entry points. Each list element is a hashref with
the following elements.

=over

=item B<url>: service URL as passed to B<efa_url>

=item B<name>: Name of the entity operating this service

=item B<shortname>: Short name of the entity

=item B<encoding>: Server-side encoding override for B<efa_encoding> (optional)

=back

=item Travel::Status::DE::EFA::service(I<$service>)

Returns a hashref describing the service I<$service>, or undef if it is not
known. See B<get_efa_urls> for the hashref layout.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item * Class::Accessor(3pm)

=item * DateTime(3pm)

=item * DateTime::Format::Strptime(3pm)

=item * JSON(3pm)

=item * LWP::UserAgent(3pm)

=back

=head1 BUGS AND LIMITATIONS

The API is not exposed completely.

=head1 SEE ALSO

efa-m(1), Travel::Status::DE::EFA::Departure(3pm).

=head1 AUTHOR

Copyright (C) 2011-2024 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
