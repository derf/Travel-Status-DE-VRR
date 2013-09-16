package Travel::Status::DE::VRR::Line;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '1.03';

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

version 1.03

=head1 DESCRIPTION

Travel::Status::DE::VRR::Line describes a tram/bus/train line departing at the
stop requested by Travel::Status::DE::VRR. Note that it only covers one
direction, so in most cases, you get two Travel::Status::DE::VRR::Line objects
per actual line.

=head1 METHODS

=head2 ACCESSORS

=over

=item $line->direction

Direction of the line.  Name of either the destination stop or one on the way.

=item $line->name

Name of the line, e.g. "U11", "SB15", "107".

=item $line->operator

Operator of the line, as in the local transit company responsible for it.

=item $line->route

Partial route of the line (as string), usually start and destination with two
stops in between.

Note that start means the actual start of the line, the stop requested by
Travel::Status::DE::VRR::Line may not even be included in this listing.

=item $line->type

Type of the line.  Observed values so far are "Bus", "NE", "StraE<szlig>enbahn",
"U-Bahn".

=item $line->valid

When / how long above information is valid.

=back

=head2 INTERNAL

=over

=item $line = Travel::Status::DE::VRR::Line->new(I<%data>)

Returns a new Travel::Status::DE::VRR::Line object.  You should not need to
call this.

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

The B<route> accessor returns a simple string, an array might be better suited.

=head1 SEE ALSO

Travel::Status::DE::VRR(3pm).

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
