package Travel::Status::DE::EFA::Stop;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '3.01';

Travel::Status::DE::EFA::Stop->mk_ro_accessors(
	qw(sched_arr rt_arr arr arr_delay
	  sched_dep rt_dep dep dep_delay
	  occupancy delay
	  place name full_name id stop_id latlon
	  platform niveau)
);

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	if ( $ref->{sched_arr} and $ref->{arr_delay} and not $ref->{rt_arr} ) {
		$ref->{rt_arr}
		  = $ref->{sched_arr}->clone->add( minutes => $ref->{arr_delay} );
	}

	if ( $ref->{sched_dep} and $ref->{dep_delay} and not $ref->{rt_dep} ) {
		$ref->{rt_dep}
		  = $ref->{sched_dep}->clone->add( minutes => $ref->{dep_delay} );
	}

	$ref->{arr} //= $ref->{rt_arr} // $ref->{sched_arr};
	$ref->{dep} //= $ref->{rt_dep} // $ref->{sched_dep};

	if (    $ref->{rt_arr}
		and $ref->{sched_arr}
		and not defined $ref->{arr_delay} )
	{
		$ref->{arr_delay}
		  = $ref->{rt_arr}->subtract_datetime( $ref->{sched_arr} )
		  ->in_units('minutes');
	}

	if (    $ref->{rt_dep}
		and $ref->{sched_dep}
		and not defined $ref->{dep_delay} )
	{
		$ref->{dep_delay}
		  = $ref->{rt_dep}->subtract_datetime( $ref->{sched_dep} )
		  ->in_units('minutes');
	}

	$ref->{delay} = $ref->{dep_delay} // $ref->{arr_delay};

	return bless( $ref, $obj );
}

sub TO_JSON {
	my ($self) = @_;

	my $ret = { %{$self} };

	for my $k (qw(sched_arr rt_arr arr sched_dep rt_dep dep)) {
		if ( $ret->{$k} ) {
			$ret->{$k} = $ret->{$k}->epoch;
		}
	}

	return $ret;
}

1;

__END__

=head1 NAME

Travel::Status::DE::EFA::Stop - Information about a stop (station) contained
in a Travel::Status::DE::EFA::Result's route

=head1 SYNOPSIS

    for my $stop ($departure->route_post) {
        printf(
            "%s -> %s : %40s %s\n",
            $stop->arr ? $stop->arr->strftime('%H:%M') : q{--:--},
            $stop->dep ? $stop->dep->strftime('%H:%M') : q{--:--},
            $stop->name, $stop->platform
        );
    }

=head1 VERSION

version 3.01

=head1 DESCRIPTION

Travel::Status::DE::EFA::Stop describes a single stop of a departure's
route. It is solely based on the respective departure's schedule;
delays or changed platforms are not taken into account.

=head1 METHODS

=head2 ACCESSORS

=over

=item $stop->arr

DateTime(3pm) object holding arrival date and time. undef if this is the
first scheduled stop.

=item $stop->dep

DateTime(3pm) object holding departure date and time. undef if this is the
final scheduled stop.

=item $stop->id

Stop ID.

=item $stop->place

City name, for instance "Essen".

=item $stop->full_name

stop name with city prefix ("I<City> I<Stop>", for instance
"Essen RE<uuml>ttenscheider Stern").

=item $stop->name

stop name without city prefix, for instance "RE<uuml>ttenscheider Stern".

=item $stop->platform

Platform name/number if available, empty string otherwise.

=back

=head2 INTERNAL

=over

=item $stop = Travel::Status::DE::EFA::Stop->new(I<%data>)

Returns a new Travel::Status::DE::EFA::Stop object.  You should not need to
call this.

=item $stop->TO_JSON

Allows the object data to be serialized to JSON.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

None known.

=head1 SEE ALSO

Travel::Status::DE::EFA(3pm).

=head1 AUTHOR

Copyright (C) 2015-2023 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
