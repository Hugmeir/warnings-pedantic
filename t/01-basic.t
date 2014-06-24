use Test::More;
use warnings::pedantic;

my $w = '';
local $SIG{__WARN__} = sub {
    $w = shift;
};

eval <<EOP;
grep 1, 1..10;
();
EOP

like(
    $w,
    qr/Unusual use of grep in void context/,
    "grep in void context"
);

eval <<EOP;
scalar(grep(1, 1..10), 3, 4, 5);
EOP

like(
    $w,
    qr/Unusual use of grep in void context/,
    "grep on the lhs of a comma operator"
);

done_testing;
