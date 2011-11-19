package Travel::Status::DE::VRR::Line;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '0.02';

Travel::Status::DE::VRR::Line->mk_ro_accessors(
	qw(direction name operator route type valid));

sub new {
	my ( $obj, %conf ) = @_;

	my $ref = \%conf;

	return bless( $ref, $obj );
}
1;

__END__

=head1 NAME

Travel::Status::DE::VRR::Line - Information about a line departing at the
requested station

=head1 SYNOPSIS

    for my $line ($status->lines) {
        printf(
            "line %s -> %s\nRoute: %s\nType %s, operator %s\nValid: %s\n\n",
            $line->name, $line->direction, $line->route,
            $line->type, $line->operator, $line->valid
        );
    }

=head1 VERSION

version 0.02

=head1 DESCRIPTION

FIXME

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
