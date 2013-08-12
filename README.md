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

And you can guess at, and issues, two-word commands:

    Tell me what to do ? climb tree
    You are in a top of an oak.
    To the East I see a meadow, beyond that a lake.

    Obvious exits:
    Down

I would like to bundle the Scott Adams games in this distribution, but it's
not clear if I can legally do this. However, I've found that you can
(legally), download the [PDA zip file](http://www.msadams.com/downloads/advpda.zip)
from [Scott Adams official download page](http://www.msadams.com/downloads.htm)
and unzip it. In the `advpda/data_scottadams` directory, you'll find a bunch
of `ADV*.DAT` files. Those are the files you should be able to play with this
interpreter:

    perl bin/scott.pl ADV01.DAT

As of this writing, not all files load properly and some load but are clearly
buggy.

# THE CODE

You probably don't want to read the code. It's mostly a straight port of the
code in `src/ScottCurses.c` (though I skipped the curses interface). As a
result, you'll see some very, very ugly code. There's a minimal test suite in
the `t/` directory and hopefully as that expands, I'll be able to refactor
this cleanly. Or better yet, I'll be able to accept your pull request to
refactor this cleanly.
