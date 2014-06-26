package warnings::pedantic;

use 5.006;
use strict;
use warnings FATAL => 'all';

=encoding UTF-8
=head1 NAME

warnings::pedantic - Dubious warnings for dubious constructs.

=head1 VERSION

Version 0.01

=cut

if (!defined &warnings::register_categories) {
    *mkMask = sub {
        my ($bit) = @_;
        my $mask = "";

        vec($mask, $bit, 1) = 1;
        return $mask;
    };

    *warnings::register_categories = sub {
        for my $package ( @_ ) {
        if (! defined $warnings::Bits{$package}) {
            $warnings::Bits{$package}     = mkMask($warnings::LAST_BIT);
            vec($warnings::Bits{'all'}, $warnings::LAST_BIT, 1) = 1;
            $warnings::Offsets{$package}  = $warnings::LAST_BIT ++;
        foreach my $k (keys %warnings::Bits) {
            vec($warnings::Bits{$k}, $warnings::LAST_BIT, 1) = 0;
        }
            $warnings::DeadBits{$package} = mkMask($warnings::LAST_BIT);
            vec($warnings::DeadBits{'all'}, $warnings::LAST_BIT++, 1) = 1;
        }
        }
    }
}

our $VERSION = '0.01';
require XSLoader;
XSLoader::load(__PACKAGE__);

my @categories;
for my $name (qw(grep close print)) {
    push @categories, "void_$name";
}

push @categories, "sort_prototype";
push @categories, "ref_assignment";

warnings::register_categories($_) for @categories;

my @offsets = map {
                    $warnings::Offsets{$_} / 2
                } @categories;

my $pedantic = 0;

$pedantic |= $_ for map { $warnings::Offsets{$_} } @categories;

use Devel::Peek;
Dump($pedantic);
exit;

start(shift, @offsets);

my %categories = map { $_ => $_ } @categories;
sub import {
    shift;
    my @import = @_ ? @_ : @categories;
    warnings->import(map { $categories{$_} } @import);
}

sub unimport {
    shift;
    my @unimport = @_ ? @_ : @categories;
    warnings->unimport(map { $categories{$_} } @unimport);
}

END { done(__PACKAGE__); }


=head1 SYNOPSIS

This module provides a C<pedantic> warning category, which, when enabled,
warns of certain extra dubious constructs.

    use warnings::pedantic;

    grep { ... } 1..10; # grep in void context
    close($fh);         # close() in void context
    print 1;            # print() in void context

=head1 DESCRIPTION    

Besides the C<pedantic> category, which enables all of the following,
the module also provides separate categories for individual groups
of warnings:

=over

=item * void_grep

Warns on void-context C<grep>:

    grep /42/, @INC;
    grep { /42/ } @INC;

This code is not particularly wrong; it's merely using grep as
an alternative to a foreach loop.

=item * void_close

Warns on void-context C<close()> and C<closedir()>:

    close($fh);
    closedir($dirh);

This is considered dubious behaviour because errors on IO operations,
such as ENOSPC, are not usually caught on the operation itself, but
on the close() of the related filehandle.

=item * void_print

Warns on void-context print(), printf(), and say():

    print();
    say();
    printf();

=item * sort_prototype

Warns when C<sort()>'s first argument is a subroutine with a prototype,
and that prototype isn't C<$$>.

    sub takes_a_block (&@) { ... }
    takes_a_block { stuff_here } @args;
    sort takes_a_block sub {...}, @args;

This probably doesn't do what the author intended for it to do.

=back

All of the warnings can be turned off with

    no warnings 'pedantic';

as well as

    no warnings;

or even

    no warnings::pedantic;

Additionally, you can turn off specific warnings with

    no warnings 'void_grep';
    no warnings 'void_close';
    no warnings 'void_print'; # printf, print, and say
    #etc

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
