package Travel::Status::DE::VRR::Result;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '0.00';

Travel::Status::DE::VRR::Result->mk_ro_accessors(
	qw(destination time platform line));

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

=head1 VERSION

version 0.00

=head1 DESCRIPTION

=head1 METHODS

=head2 ACCESSORS

=over

=back

=head2 INTERNAL

=over

=back

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

=head1 AUTHOR

Copyright (C) 2011 by Daniel Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
