package Travel::Status::DE::VRR::Result;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '1.03';

Travel::Status::DE::VRR::Result->mk_ro_accessors(
	qw(countdown date delay destination info line lineref platform
	  platform_db sched_date sched_time time type)
);

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}
1;

__END__

=head1 NAME

Travel::Status::DE::VRR::Result - Information about a single
departure received by Travel::Status::DE::VRR

=head1 SYNOPSIS

    for my $departure ($status->results) {
        printf(
            "At %s: %s to %s from platform %s\n",
            $departure->time, $departure->line, $departure->destination,
            $departure->platform
        );
    }

=head1 VERSION

version 1.03

=head1 DESCRIPTION

Travel::Status::DE::VRR::Result describes a single departure as obtained by
Travel::Status::DE::VRR.  It contains information about the time, platform,
line number and destination.

=head1 METHODS

=head2 ACCESSORS

"Actual" in the description means that the delay (if available) is already
included in the calculation, "Scheduled" means it isn't.

=over

=item $departure->countdown

Actual time in minutes from now until the tram/bus/train will depart.

If delay information is available, it is already included.

=item $departure->date

Actual departure date (DD.MM.YYYY).

=item $departure->delay

Expected delay from scheduled departure time in minutes.

Note that this is only available for DB trains, in other cases it will always
return 0.

=item $departure->destination

Destination name.

=item $departure->info

Additional information related to the departure (string).  If departures for
an address were requested, this is the stop name, otherwise it may be recent
news related to the line's schedule.  If no information is available, returns
an empty string.

=item $departure->line

The name/number of the line.

=item $departure->lineref

Travel::Status::DE::VRR::Line(3pm) object describing the departing line in
detail.

=item $departure->platform

Departure platform number.

=item $departure->platform_db

true if the platform number is operated by DB ("Gleis x"), false ("Bstg. x")
otherwise.

Unfortunately, there is no distinction between tram and bus platforms yet,
which also may have the same numbers.

=item $departure->sched_date

Scheduled departure date (DD.MM.YYYY).

=item $departure->sched_time

Scheduled departure time (HH:MM).

=item $departure->time

Actual departure time (HH:MM).

=item $departure->type

Type of the departure.  Note that efa.vrr.de sometimes puts bogus data in this
field.  See L</DEPARTURE TYPES>.

=back

=head2 INTERNAL

=over

=item $departure = Travel::Status::DE::VRR::Result->new(I<%data>)

Returns a new Travel::Status::DE::VRR::Result object.  You should not need to
call this.

=back

=head1 DEPARTURE TYPES

The following are known so far:

=over

=item * Abellio-Zug

=item * Eurocity

=item * Intercity-Express

=item * NE (NachtExpress / night bus)

=item * Niederflurbus

=item * R-Bahn (RE / RegionalExpress)

=item * S-Bahn

=item * SB (Schnellbus)

=item * StraE<szlig>enbahn

=item * U-Bahn

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

C<< $result->type >> may contain bogus data.  This comes from the efa.vrr.de
interface.

=head1 SEE ALSO

Travel::Status::DE::VRR(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
