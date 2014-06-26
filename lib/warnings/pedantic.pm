package warnings::pedantic;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

warnings::pedantic - Dubious warnings for dubious constructs.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
require XSLoader;
XSLoader::load(__PACKAGE__);


my @categories = 'pedantic';

for my $name (qw(grep close print)) {
    push @categories, "void_$name";
}

push @categories, "sort_prototype";

warnings::register_categories($_) for @categories;

my @offsets = map {
                    $warnings::Offsets{$_} / 2
                } @categories;

start(shift, $offsets[0]);

sub import {
    warnings->import(@categories);
}

sub unimport {
    warnings->unimport(@categories);
}

END { done(__PACKAGE__); }


=head1 SYNOPSIS

This module provides a 'pedantic' warning category, which, when enabled,
warns of certain extra dubious constructs.

    use warnings::pedantic;

    grep { ... } 1..10; # grep in void context
    close($fh);         # close() in void context
    print 1;            # print() in void context
    
Warnings can be turned off with

    no warnings 'pedantic';

as well as

    no warnings;

or

    no warnings::pedantic;

Additionally, you can turn off specific warnings with

    no warnings 'void_grep';
    no warnings 'void_close';
    no warnings 'void_print'; # printf, print, and say

=head1 AUTHOR

Brian Fraser, C<< <fraserbn at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-warnings-pedantic at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=warnings-pedantic>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

The warning for void-context grep was at one point part of the Perl core,
but was deemed too controversial and was removed.
Ævar Arnfjörð Bjarmason recently attempted to get it back to the core as
part of an RFC to extend warnings.pm, which in turn inspired this module.

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Brian Fraser.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of warnings::pedantic
