CREATE OR REPLACE FUNCTION Diff(
_Original text,
_New text
) RETURNS TEXT AS $BODY$
use Algorithm::Diff;
my $in = {};
@{$in->{old}} = split "\n", $_[0];
@{$in->{new}} = split "\n", $_[1];
my @diff = Algorithm::Diff::sdiff($in->{old},$in->{new});
my $str;
my $line_num = 0;
for my $d (@diff) {
    $line_num++;
    next if $d->[0] eq 'u';
    $str .= $line_num . ' ' . $d->[0] . ' ' . $d->[1] . "\n";
    $str .= $line_num . ' ' . $d->[0] . ' ' . $d->[2] . "\n";
    $str .= "\n";
}
return $str;
$BODY$ LANGUAGE plperlu VOLATILE;
