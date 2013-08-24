# NAME

Scott Adams game driver written in Perl

# VERSION

0.01

# SYNOPSIS

    perl bin/scott.pl <adventure database>
    perl bin/scott.pl games/the_count.dat

# DESCRIPTION

This is __ALPHA__ code. It probably has bugs, but seems to work pretty well so
far. Once `save game` and `load game` commands work, this should be in
__BETA__ and work on cleaning up the internals can begin.

This is a pure Perl driver for the old [Scott Adams games](http://en.wikipedia.org/wiki/Scott_Adams_\(game_designer\)).
The `save game` and `load game` functions are not yet implemented. Patches
very welcome (and it should be an easy task).

If you play it with the mini-adventure in the test suite, you'll see a
starting screen similar to this:

    Version 4.16 of Adventure

    You are in a forest

    Obvious exits:
    North, South, East, West

    You can also see:
      - Trees

    A voice BOOOOMS out:
    Welcome to Adventure number: 1 `ADVENTURELAND`.
    In this adventure you have to find *TREASURES* and store them away.

    To see how well you're doing say: `SCORE`
    Remember you can always say `HELP`

    Tell me what to do ?

The commands are something you guess at, are limited to two words and for most
games, only the first three letters of each word matters.

    Tell me what to do ? climb tree
    You are in a top of an oak.
    To the East I see a meadow, beyond that a lake.

    Obvious exits:
    Down

Scott Adams has graciously agreed to allow me to bundle his games with this
distribution and they are included in the `games` directory. Please see the
[Scott Adams official Web site](http://www.msadams.com/) for more information
about copyright and to read more about his history and the history of these
fun games.
    
You can run a game with the following:

    perl bin/scott.pl games/pirate_adventure.dat

As of this writing, there appear to be a few bugs and I don't have the 'save'
or 'load' functionality written.

# THE CODE

You probably don't want to read the code. It's mostly a straight port of the
code in `src/ScottCurses.c` (though I skipped the curses interface). As a
result, you'll see some very, very ugly code. There's a minimal test suite in
the `t/` directory and hopefully as that expands, I'll be able to refactor
this cleanly. Or better yet, I'll be able to accept your pull request to
refactor this cleanly.

If you want to hack, you should read the `Definition` file to understand how
the game databases are designed, and `src/ScottCurses.c` is the (working) C
source code.

If you really want to play the games and not wait for the Perl implementation
to be finished, you can run `make` and then you'll find `bin/ScottCurses`:

    bin/ScottCurses games/pirate_adventure.dat

For hacking, it's great to be able to run both games side-by-side with the
`-a` (action) switch to compare divergences in behavior:

    bin/ScottCurses -a games/mini-adventure.dat 2>c_trace.txt
    bin/scott.pl    -a games/mini-adventure.dat 2>perl_trace.txt
    vimdiff c_trace.txt perl_trace.txt

When you do this, enter the exact same series of commands for each and
`ctrl-c` to exit when you've gotten to the point where behavior diverges
(don't hit `q` to exit in the Perl code or you'll get a spurious trace
difference).

That usually shows where the code paths diverge.
