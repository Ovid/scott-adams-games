use Test::Most 'bail';
use FindBin;
require "$FindBin::Bin/../bin/scott.pl";

my $database = 't/data/adv00';

::LoadDatabase($database);

ok ::strncasecmp('HIT', 'hIt', 3),
	'We should be able to do a case-insensitive match to the correct number of characters';
ok !::strncasecmp('HIT', 'KIl', 3),
	'... but not if the words are different';

is ::MapSynonym('ax'), 'AXE', '"ax" should be a synonym for "AXE"';
is ::MapSynonym('axE'), 'AXE', '"axE" should be a synonym for "AXE"';
is ::MapSynonym('MIR'), 'MIR', '"MIR" should be a synonym for "MIR"';
is ::MapSynonym('mirror'), 'MIR', '"mirror" should be a synonym for "MIR"';
ok !defined ::MapSynonym('XXX'), '"XXX" should not be a synonym for anything';

is ::WhichWord( 'ax',  \@::Nouns ), 11, 'WhichWord("ax", Nouns) should return its id';
is ::WhichWord( 'axE', \@::Nouns ), 11, 'WhichWord("axE", Nouns) should return the same id';
is ::WhichWord( 'MIR', \@::Nouns ), 10, '"MIR" should return its id';
ok !defined ::WhichWord( 'XXX', \@::Nouns ), '"XXX" should not be a synonym for anything';

is ::WhichWord( 'at',  \@::Verbs ), 7, '"at" should be a synonym for "AT"';
is ::WhichWord( 'cUt', \@::Verbs ), 8, '"cUt" should be a synonym for "CHO"';
is ::WhichWord( 'CHO', \@::Verbs ), 8, '"CHO" should be a synonym for "CHO"';
ok !defined ::WhichWord( 'XXX', \@::Verbs ), '"XXX" should not be a synonym for anything';

is ::MatchUpItem('ax', 2), -1,
	'If an item is not at the specified location, MatchUpItem should return -1';
is ::MatchUpItem('ax', 10), 11,
	'... otherwise, it should return the index number of the item';
is ::MatchUpItem('sign', 3), -1,
	'... but only if we can "GET" that item';

my $expected_starting_look = <<'END';
You are in a forest

Obvious exits:
North, South, East, West

You can also see:
Trees
END

is ::Look(), $expected_starting_look,
	'... and our starting Look() should reveal the correct location';

done_testing;
