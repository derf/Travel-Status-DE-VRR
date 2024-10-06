package Travel::Status::DE::EFA::Info;

use strict;
use warnings;
use 5.010;

use parent 'Class::Accessor';

our $VERSION = '3.01';

Travel::Status::DE::EFA::Info->mk_ro_accessors(
	qw(link_url link_text subject content subtitle additional_text));

sub new {
	my ( $obj, %opt ) = @_;

	my $json = $opt{json};

	my $ref = {
		param           => {},
		link_url        => $json->{infoLinkURL},
		link_text       => $json->{infoLinkText},
		subject         => $json->{infoText}{subject},
		content         => $json->{infoText}{content},
		subtitle        => $json->{infoText}{subtitle},
		additional_text => $json->{infoText}{additionalText},
	};

	for my $param ( @{ $json->{paramList} // [] } ) {
		$ref->{param}{ $param->{name} } = $param->{value};
	}

	return bless( $ref, $obj );
}

sub TO_JSON {
	my ($self) = @_;

	return { %{$self} };
}

1;

__END__

=head1 NAME

Travel::Status::DE::EFA::Info - Information about a station

=head1 SYNOPSIS

=head1 VERSION

version 3.01

=head1 DESCRIPTION

Travel::Status::DE::EFA::Info describes a tram/bus/train line departing at the
stop requested by Travel::Status::DE::EFA. Note that it only covers one
direction, so in most cases, you get two Travel::Status::DE::EFA::Info objects
per actual line.

=head1 METHODS

=head2 ACCESSORS

=head1 DIAGNOSTICS

None.

=head1 DEPENDENCIES

=over

=item Class::Accessor(3pm)

=back

=head1 BUGS AND LIMITATIONS

The B<route> accessor returns a simple string, an array might be better suited.

=head1 SEE ALSO

Travel::Status::DE::EFA(3pm).

=head1 AUTHOR

Copyright (C) 2024 by Birte Kristina Friesel E<lt>derf@finalrewind.orgE<gt>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
