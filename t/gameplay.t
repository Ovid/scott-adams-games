use Test::Most 'bail';
use FindBin;
require "$FindBin::Bin/../bin/scott.pl";
use Capture::Tiny 'capture_stdout';
use Carp;

my $database = 't/data/adv00';
::LoadDatabase($database);

# set up initial words
my %NOUNS = _get_nouns();
my %VERBS = _get_verbs();

sub is_similar($$;$);
sub look      { Look() }

#
# Actual start of tests
#

my $look = look;
is_similar look, <<'END', 'starting area should be ok';
You are in a forest

Obvious exits:
 North, South, East, West

 You can also see:
   - Trees
END

is_similar doit(qw/take all/), 'Nothing taken',
    'Trying to take things we cannot take should fail';
is_similar doit(qw/take ax/) , 'It is beyond your power to do that',
    'Trying to take something that is not there should fail';

is_similar doit(qw/go east/), <<'END', 'meadow';
You are in a sunny meadow

Obvious exits:
South, East, West

You can also see:
  - Large sleeping dragon
  - Sign here says `In many cases mud is good. In others...`
END

is_similar doit(qw/go east/), <<'END', 'lakeshore';
I'm on the shore of a lake

Obvious exits:
North, South, West

You can also see:
  - Water
  - Fish
  - Rusty axe (Magic word `BUNYON` on it)
  - Sign says `No swimming allowed here`
END

subtest 'take/drop' => sub {
    is_similar doit(qw/take all/), <<'END', 'take all';
    Fish: O.K.
    Rusty axe (Magic word `BUNYON` on it): O.K.
END

    my $look = look;
    unlike $look, qr/Fish/, 'The scene should no longer describe the fish we took';
    unlike $look, qr/Rusty axe/, '... or the axe';

    is_similar doit(qw/drop all/), <<'END', 'drop all';
    Fish: O.K.
    Rusty axe (Magic word `BUNYON` on it): O.K.
END

    $look = look;
    like $look, qr/Fish/, 'The scene should now describe the fish we dropped';
    like $look, qr/Rusty axe/, '... and the axe';

$ENV{DEBUG} = 1;
    is_similar doit(qw/take fish/), 'O.K.', 'take fish';

    $look = look;
    unlike $look, qr/Fish/, 'The scene should no longer describe the fish we took';
    like $look, qr/Rusty axe/, '... but the axe should still be there';

    is_similar doit(qw/drop fish/), 'O.K.', 'drop fish';

    $look = look;
    like $look, qr/Fish/, 'The scene should now describe the fish we dropped';
    like $look, qr/Rusty axe/, '... and the axe';
};

done_testing;

sub is_similar($$;$) {
    my ( $have, $lines, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @want = split /\n/ => $lines;
    foreach my $want (@want) {
        next unless $want =~ /\S/;
        $want =~ s/^\s+|\s+$//g;    # trim
        my $name = $message // "Lines are similar";
        $name .= ": $want";
        like $have, qr/\Q$want/, $name;
    }
}

sub doit {
    my ($verb, $noun) = @_;
    unless ( exists $VERBS{$verb} ) {
        croak("Unknown verb: $verb");
    }
    $::NounText = $noun // '';
    if ( $noun && 'all' ne lc($noun) && !exists $NOUNS{$noun}) {
        croak("Unknown noun: $noun");
    }

    my $output = capture_stdout{
        PerformActions($VERBS{$verb}, $NOUNS{$noun});
    };
    return $output;
}

sub _get_nouns {
    my %nouns;
    my @nouns = qw(north south east west up down ax fish);
    foreach (@nouns) {
        no warnings 'once';
        $nouns{$_} = WhichWord( $_, \@::Nouns ) or fail "Bad noun: $_";
    }
    return %nouns;
}

sub _get_verbs {
    my %verbs;
    my @verbs = qw(go take drop);
    foreach (@verbs) {
        no warnings 'once';
        $verbs{$_} = WhichWord( $_, \@::Verbs ) or fail "Bad verb: $_";
    }
    return %verbs;
}

