package warnings::pedantic;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

warnings::pedantic - The great new warnings::pedantic!

=head1 VERSION

Version 0.01

=cut

require Carp;


our $VERSION = '0.01';
require XSLoader;
XSLoader::load(__PACKAGE__);

warnings::register_categories('pedantic');
start(shift, $warnings::Offsets{pedantic}/2);

sub import {
    warnings->import('pedantic');
}

sub unimport {
    warnings->unimport('pedantic');
}

END { done(__PACKAGE__); }


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use warnings::pedantic;

    my $foo = warnings::pedantic->new();
    ...

=head1 AUTHOR

Brian Fraser, C<< <fraserbn at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-warnings-pedantic at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=warnings-pedantic>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc warnings::pedantic


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=warnings-pedantic>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/warnings-pedantic>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/warnings-pedantic>

=item * Search CPAN

L<http://search.cpan.org/dist/warnings-pedantic/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Brian Fraser.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of warnings::pedantic
