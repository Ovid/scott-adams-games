use Test::Most;
use lib 't/lib';
use TestAdventure 't/data/adv00';

my $look = look;
is_similar look, <<'END', 'starting area should be ok';
You are in a forest

Obvious exits:
 North, South, East, West

 You can also see:
   - Trees
END

is_similar doit('take all'), 'Nothing taken',
    'Trying to take things we cannot take should fail';
is_similar doit('take ax') , 'It is beyond your power to do that',
    'Trying to take something that is not there should fail';

is_similar doit('go east'), <<'END', 'meadow';
You are in a sunny meadow

Obvious exits:
South, East, West

You can also see:
  - Large sleeping dragon
  - Sign here says `In many cases mud is good. In others...`
END

is_similar doit('go east'), <<'END', 'lakeshore';
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
    is_similar doit('take all'), <<'END', 'take all';
    Fish: O.K.
    Rusty axe (Magic word `BUNYON` on it): O.K.
END

    my $look = look;
    unlike $look, qr/Fish/, 'The scene should no longer describe the fish we took';
    unlike $look, qr/Rusty axe/, '... or the axe';

    is_similar doit('drop all'), <<'END', 'drop all';
    Fish: O.K.
    Rusty axe (Magic word `BUNYON` on it): O.K.
END

    $look = look;
    like $look, qr/Fish/, 'The scene should now describe the fish we dropped';
    like $look, qr/Rusty axe/, '... and the axe';

    is_similar doit('take fish'), 'O.K.', 'take fish';

    $look = look;
    unlike $look, qr/Fish/, 'The scene should no longer describe the fish we took';
    like $look, qr/Rusty axe/, '... but the axe should still be there';

    is_similar doit('drop fish'), 'O.K.', 'drop fish';

    $look = look;
    like $look, qr/Fish/, 'The scene should now describe the fish we dropped';
    like $look, qr/Rusty axe/, '... and the axe';
};

done_testing;
