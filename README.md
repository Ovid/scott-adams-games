# NAME

Scott Adams game driver written in Perl

# VERSION

0.01

# SYNOPSIS

    perl bin/scott.pl <adventure database>

# DESCRIPTION

This is __ALPHA__ code. It's not guaranteed to work and certainly has bugs.

This is a pure Perl driver for the old [Scott Adams games](http://en.wikipedia.org/wiki/Scott_Adams_\(game_designer\)).
The `save` and `load` functions are not yet implemented.

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
