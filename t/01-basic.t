use Test::More;
use warnings::pedantic;

my $w = '';
BEGIN {
    $SIG{__WARN__} = sub {
        $w .= shift;
    };
}

BEGIN {
    
    open my $fh, ">", *STDIN;
    close($fh);
    like($w, qr/\QUnusual use of close() in void context/, "works in a BEGIN block");
    $w = '';
}

eval <<EOP;
grep 1, 1..10;
();
EOP

like(
    $w,
    qr/Unusual use of grep in void context/,
    "grep in void context"
);
$w = '';

{
    no warnings 'void_grep';
    eval <<EOP;
    grep 1, 1..10;
    ();
EOP

    is(
        $w,
        '',
        "can turn off an specific warning (void_grep)"
    );
    $w = '';
}

eval <<EOP;
scalar(grep(1, 1..10), 3, 4, 5);
EOP

like(
    $w,
    qr/Unusual use of grep in void context/,
    "grep on the lhs of a comma operator"
);
$w = '';

eval <<'EOP';
open my $fh, "<", *STDIN;
print $fh 1;
printf $fh 1;
close $fh;
close($fh), 1, 2, 3;
EOP

like(
    $w,
    qr/Suspect use of \b\Q$_()\E in void context/,
    "void context $_"
) for qw(printf print);

like(
    $w,
    qr/\QUnusual use of close() in void context/,
    "close() in void context"
);
$w = '';

eval <<'EOP';
package foobar;
sub foo {1};
sub bar ($$) {1};
sub doof (&$) {1};
() = sort foo  1..10;
() = sort bar  1..10;
() = sort doof 1..10;
EOP

like(
    $w,
    qr/\A\QSubroutine foobar::doof() used as first argument to sort, but has a &\E\$ prototype/,
    'sort foo, with foo(&$)'
);
$w = '';

done_testing;
