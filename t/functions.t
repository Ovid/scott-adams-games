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
ok !defined ::MapSynonym('XXX'), '"XXX" should not be a synonym for anything';

done_testing;
