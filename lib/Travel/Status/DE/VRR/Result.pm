package Travel::Status::DE::VRR::Result;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '0.01';

Travel::Status::DE::VRR::Result->mk_ro_accessors(
	qw(destination time platform line info));

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

version 0.01

=head1 DESCRIPTION

Travel::Status::DE::VRR::Result describes a single departure as obtained by
TRavel::Status::DE::VRR.  It contains information about the time, platform,
line number and destination.

=head1 METHODS

=head2 ACCESSORS

=over

=item $departure->destination

The tram/bus/train destination.

=item $departure->info

Additional information related to the departure (string).  If departures for
an address were requested, this is the stop name, otherwise it may be recent
news related to the line's schedule.

=item $departure->line

The name/number of the line.

=item $departure->platform

The departure platform.  Note that this is prefixed by either "Bstg." (for
tram/bus departures) or "Gleis" (for trains).

=item $departure->time

The departure time as string in "HH:MM" format.

=back

=head2 INTERNAL

=over

=item $departure = Travel::Status::DE::VRR::Result->new(I<%data>)

Returns a new Travel::Status::DE::VRR::Result object.  You should not need to
call this.

Required I<data>:

=over

=item B<destination> => I<string>

=item B<line> => I<string>

=item B<platform> => I<string>

=item B<time> => I<string>

=back

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

Unknown.

=head1 SEE ALSO

Travel::Status::DE::VRR(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
