#!/usr/bin/env perl

use strict;
use warnings 'FATAL' => 'all';
use 5.010;
use Getopt::Long;
use autodie ':all';
use Carp 'croak';
use Carp::Always;
use Storable 'dclone';
$|++;

use Data::Dumper::Simple;
local $Data::Dumper::Indent   = 1;
local $Data::Dumper::Sortkeys = 1;

# verbs
use constant AUT       => 0;
use constant GO        => 1;
use constant JUMP      => 6;
use constant AT        => 7;
use constant CHO       => 8;
use constant GET       => 10;
use constant LIG       => 14;
use constant DROP      => 18;
use constant THR       => 24;
use constant QUI       => 26;
use constant SWI       => 27;
use constant RUB       => 28;
use constant LOO       => 29;
use constant STO       => 32;
use constant SCO       => 33;
use constant INVENTORY => 34;
use constant SAV       => 35;
use constant WAK       => 36;
use constant UNL       => 37;
use constant REA       => 38;
use constant ATT       => 39;
use constant DRI       => 42;
use constant FIN       => 45;
use constant HEL       => 47;
use constant SAY       => 48;
use constant SCR       => 51;
use constant FIL       => 55;
use constant CRO       => 56;
use constant DAM       => 57;
use constant MAK       => 58;
use constant WAV       => 60;
use constant OPE       => 69;

# nouns


# misc
use constant LIGHT_SOURCE => 9;      # #  Always 9 how odd
use constant CARRIED      => 255;    # #  Carried
use constant DESTROYED    => 0;      # #  Destroyed
use constant DARKBIT      => 1;      #
use constant LIGHTOUTBIT  => 16;     # #  Light gone out

our $SECOND_PERSON    = 1;           # "you are" instead of "I am";
our $SCOTTLIGHT       = 0;           #    #  Authentic Scott Adams light messages
our $DEBUGGING        = 0;           #    #  Info from database load
our $TRS80_STYLE      = 0;           #    #  Display in style used on TRS-80
our $PREHISTORIC_LAMP = 1;           #    #  Destroy the lamp (very old databases)

our @Items;
our @Rooms;
our @Verbs;
our @Nouns;
our @Messages;

#Action *Actions;
our $LightRefill;
our $NounText;

my @Counters;    #  Range unknown
my $CurrentCounter = 0;
my $SavedRoom;
my @RoomSaved;    #  Range unknown
my $DisplayUp;        #  Curses up
#WINDOW *Top,*Bottom;
my $Redraw;        #  Update item window
our $Options = 0;     #     #  Option flags set
our $Width;           #       #  Terminal width
our $TopHeight;       #       #  Height of top window
our $BottomHeight;    #   #  Height of bottom window

#     NumWords        #  Smaller of verb/noun is padded to same size
our %GameHeader = map { $_ => 0 } qw(
  Unknown1
  NumItems
  NumActions
  NumWords
  NumRooms
  MaxCarry
  PlayerRoom
  Treasures
  WordLength
  LightTime
  NumMessages
  TreasureRoom
  Unknown2
);

our @Actions;

#
#typedef struct
#{
#    char *Text;
#    short Exits[6];
#} Room;
#
#typedef struct
#{
#    short Version;
#    short AdventureNumber;
#    short Unknown;
#} Tail;
#
sub strncasecmp {
    my ( $word1, $word2, $length ) = @_;
    return lc( substr $word1, 0, $length ) eq lc( substr $word2, 0, $length );
}

sub MapSynonym {
    my $word = shift;
    my $lastword;

    for my $i ( 0 .. $GameHeader{NumWords} ) {
        my $curr_word = $Nouns[$i];
        unless ( $curr_word =~ s/^\*// ) {
            $lastword = $curr_word;
        }
        if ( strncasecmp( $curr_word, $word, $GameHeader{WordLength} ) ) {
            return $lastword;
        }
    }
    return;
}

sub WhichWord {
    my ( $word, $list ) = @_;
    my $lastword;
    foreach my $index ( 0 .. $GameHeader{NumWords} ) {
        my $curr_word = $list->[$index];
        unless ( $curr_word =~ s/^\*// ) {
            $lastword = $index;
        }
        if ( strncasecmp( $curr_word, $word, $GameHeader{WordLength} ) ) {
            return $lastword;
        }
    }
    return;
}

sub MatchUpItem {
    my ( $text, $loc ) = @_;
    my $word = MapSynonym($text) // $text;

    for my $i ( 0 .. $GameHeader{NumItems} ) {
        my $item = $Items[$i];
        if (   $item->{AutoGet}
            && $item->{Location} == $loc
            && strncasecmp( $item->{AutoGet}, $word, $GameHeader{WordLength} ) )
        {
            return $i;
        }
    }
    return;
}

#
use constant TRS80_LINE => "\n<------------------------------------------------------------>\n";

#
sub MyLoc { $GameHeader{PlayerRoom} }

#
my $BitFlags = 0;    #   #  Might be >32 flags - I haven't seen >32 yet

sub RandomPercent {
    my $n  = shift;
    my $rv = rand() << 6;
    $rv %= 100;
    return $rv < $n;
}

sub CountCarried {
    my $num = 0;
    for my $ct ( 0 .. $GameHeader{NumItems} ) {
        if ( $Items[$ct]{Location} == CARRIED ) {
            $num++;
        }
    }
    return ($num);
}

#
#void LineInput(char *buf)
#{
#    int pos=0;
#    int ch;
#    while(1)
#    {
#        wrefresh(Bottom);
#        ch=wgetch(Bottom);
#        switch(ch)
#        {
#            case 10:;
#            case 13:;
#                buf[pos]=0;
#                scroll(Bottom);
#                wmove(Bottom,$BottomHeight,0);
#                return;
#            case 8:;
#            case 127:;
#                if(pos>0)
#                {
#                    int y,x;
#                    getyx(Bottom,y,x);
#                    x--;
#                    if(x==-1)
#                    {
#                        x=$Width-1;
#                        y--;
#                    }
#                    mvwaddch(Bottom,y,x,' ');
#                    wmove(Bottom,y,x);
#                    wrefresh(Bottom);
#                    pos--;
#                }
#                break;
#            default:
#                if(ch>=' '&&ch<=126)
#                {
#                    buf[pos++]=ch;
#                    waddch(Bottom,(char)ch);
#                    wrefresh(Bottom);
#                }
#                break;
#        }
#    }
#}
#
sub GetInput {
    say '-' x 80;
    GetInput: while (1) {
        print "Tell me what to do ? ";
        chomp( my $input = <STDIN> );

        my @words = split ' ' => $input, 2;
        if ( @words > 2 ) {
            say "I'm stupid. Try one or two words.";
            next GetInput;
        }
        unless (@words) {
            say "Huh?";
            next GetInput;
        }
        my ( $verb, $noun ) = @words;
        if ( !defined $noun && 1 == length($verb) ) {
            given ($verb) {
                when ('n') { $verb = 'NORTH' }
                when ('s') { $verb = 'SOUTH' }
                when ('e') { $verb = 'EAST' }
                when ('w') { $verb = 'WEST' }
                when ('d') { $verb = 'DOWN' }
                when ('u') { $verb = 'UP' }

                # Brian Howarth interpreter also supports this
                when ('i') { $verb = 'INVENTORY' }
            }
        }
        $noun //= '';
        my $nc = WhichWord( $verb, \@Nouns );
        my $vc;

        # The Scott Adams system has a hack to avoid typing 'go' */
        if ( defined $nc && $nc >= 1 && $nc <= 6 ) {
            $vc = 1;
        }
        else {
            $vc = WhichWord( $verb, \@Verbs );
            $nc = WhichWord( $noun, \@Nouns );
        }
        $NounText = $noun;    # Needed by GET/DROP hack
        if ( !defined $vc ) {
            say("You use word(s) I don't know! ");
        }
        else {
            return ( $vc, $nc );
        }
    }
}

#
#void SaveGame()
#{
#    char buf[256];
#    int ct;
#    FILE *f;
#    say("Filename: ");
#    LineInput(buf);
#    say("\n");
#    f=fopen(buf,"w");
#    if(f==NULL)
#    {
#        say("Unable to create save file.\n");
#        return;
#    }
#    for(ct=0;ct<16;ct++)
#    {
#        fprintf(f,"%d %d\n",Counters[ct],RoomSaved[ct]);
#    }
#    fprintf(f,"%ld %d %hd %d %d %hd\n",BitFlags, (BitFlags&(1<<DARKBIT))?1:0,
#        MyLoc,CurrentCounter,SavedRoom,$GameHeader{LightTime});
#    for(ct=0;ct<=$GameHeader{NumItems};ct++)
#        fprintf(f,"%hd\n",(short)$Items[$ct]{Location});
#    fclose(f);
#    say("Saved.\n");
#}
#
#void LoadGame(char *name)
#{
#    FILE *f=fopen(name,"r");
#    int ct=0;
#    short lo;
#    short DarkFlag;
#    if(f==NULL)
#    {
#        say("Unable to restore game.");
#        return;
#    }
#    for(ct=0;ct<16;ct++)
#    {
#        fscanf(f,"%d %d\n",&Counters[ct],&RoomSaved[ct]);
#    }
#    fscanf(f,"%ld %d %hd %d %d %hd\n",
#        &BitFlags,&DarkFlag,&MyLoc,&CurrentCounter,&SavedRoom,
#        &$GameHeader{LightTime});
#    #  Backward compatibility
#    if(DarkFlag)
#        BitFlags|=(1<<15);
#    for(ct=0;ct<=$GameHeader{NumItems};ct++)
#    {
#        fscanf(f,"%hd\n",&lo);
#        $Items[$ct]{Location}=(unsigned char)lo;
#    }
#    fclose(f);
#}
#
sub PerformLine {
    my $ct = shift;
    my $continuation=0;
    my ( @param,$pptr );
    my @act;
    my $cc=0;
    while($cc<5)
    {
        my $cv = $Actions[$ct]{Condition}[$cc];
        my $dv = $cv / 20;
        $cv %= 20;
        given ($cv) {
            when (0) {
                $param[ $pptr++ ] = $dv;
            }
            when (1) {
                if ( $Items[$dv]{Location} != CARRIED ) { return (0); }
            }
            when (2) {
                if ( $Items[$dv]{Location} != MyLoc ) { return (0); }
            }
            when (3) {
                if ( $Items[$dv]{Location} != CARRIED && $Items[$dv]{Location} != MyLoc ) { return (0); }
            }
            when (4) {
                if ( MyLoc != $dv ) { return (0); }
            }
            when (5) {
                if ( $Items[$dv]{Location} == MyLoc ) { return (0); }
            }
            when (6) {
                if ( $Items[$dv]{Location} == CARRIED ) { return (0); }
            }
            when (7) {
                if ( MyLoc == $dv ) { return (0); }
            }
            when (8) {
                if ( ( $BitFlags & ( 1 << $dv ) ) == 0 ) { return (0); }
            }
            when (9) {
                if ( $BitFlags & ( 1 << $dv ) ) { return (0); }
            }
            when (10) {
                if ( CountCarried() == 0 ) { return (0); }
            }
            when (11) {
                if ( CountCarried() ) { return (0); }
            }
            when (12) {
                if ( $Items[$dv]{Location} == CARRIED || $Items[$dv]{Location} == MyLoc ) { return (0); }
            }
            when (13) {
                if ( $Items[$dv]{Location} == 0 ) { return (0); }
            }
            when (14) {
                if ( $Items[$dv]{Location} ) { return (0); }
            }
            when (15) {
                if ( $CurrentCounter > $dv ) { return (0); }
            }
            when (16) {
                if ( $CurrentCounter <= $dv ) { return (0); }
            }
            when (17) {
                if ( $Items[$dv]{Location} != $Items[$dv]{InitialLoc} ) { return (0); }
            }
            when (18) {
                if ( $Items[$dv]{Location} == $Items[$dv]{InitialLoc} ) { return (0); }
            }
            when (19) {    #  Only seen in Brian Howarth games so far
                if ( $CurrentCounter != $dv ) { return (0); }
            }
        }
        $cc++;
    }
#    #  Actions
    $act[0] = $Actions[$ct]{Action}[0];
    $act[2] = $Actions[$ct]{Action}[1];
    $act[1] = $act[0] % 150;
    $act[3] = $act[2] % 150;
    $act[0] /= 150;
    $act[2] /= 150;
    $cc   = 0;
    $pptr = 0;
    while($cc<4)
    {
        if($act[$cc]>=1 && $act[$cc]<52)
        {
            say(Messages[$act[$cc]]);
            say("\n");
        }
        elsif($act[$cc]>101)
        {
            say(Messages[$act[$cc]-50]);
            say("\n");
        }
        else {
            given($act[$cc])
        {
            when (0) {#  NOP
            }
            when (52) {
                if(CountCarried()==$GameHeader{MaxCarry})
                {
                    if($SECOND_PERSON)
{                        say("You are carrying too much. ");}
                    else
{                        say("I've too much to carry! ");}
                }
                }
                if($Items[$param[$pptr]]{Location}==MyLoc)
{                    $Redraw=1;}
                $Items[$param[$pptr++]]{Location}= CARRIED;
            }
            when (53) {
                $Redraw=1;
                $Items[$param[$pptr++]]{Location}=MyLoc;
            }
            when (54) {
                $Redraw=1;
                $GameHeader{PlayerRoom} =$param[$pptr++];
            }
            when (55) {
                if($Items[$param[$pptr]]{Location}==MyLoc)
{                    $Redraw=1;}
                $Items[$param[$pptr++]]{Location}=0;
            }
            when (56) {
                $BitFlags|=1<<DARKBIT;
            }
            when (57) {
                $BitFlags&=~(1<<DARKBIT);
            }
            when (58) {
                $BitFlags|=(1<<$param[$pptr++]);
            }
            when (59) {
                if($Items[$param[$pptr]]{Location}==MyLoc)
{                    $Redraw=1;}
                $Items[$param[$pptr++]]{Location}=0;
            }
            when (60) {
                $BitFlags&=~(1<<$param[$pptr++]);
            }
            when (61) {
                if($SECOND_PERSON)
{                    say("You are dead.\n");}
                else
{                    say("I am dead.\n");}
                $BitFlags&=~(1<<DARKBIT);
                $GameHeader{PlayerRoom} = $GameHeader{NumRooms};    #  It seems to be what the code says!
                say Look();
            }
            when (62) {
            {
                #  Bug fix for some systems - before it could get parameters wrong
                my $i=$param[$pptr++];
                $Items[$i]{Location}=$param[$pptr++];
                $Redraw=1;
            }
            }
            when (63) {
doneit:                say("The game is now over.\n");
                #wrefresh(Bottom);
                sleep(5);
                #endwin();
                exit(0);
            when (64) {
                say Look();
            }
            when (65) {
            {
                my $ct=0;
                my $n=0;
                while($ct<=$GameHeader{NumItems})
                {
                    if($Items[$ct]{Location}==$GameHeader{TreasureRoom} &&
                      $Items[$ct]{Text}=~/^\*/)
{                          $n++;}
                    $ct++;
                }
                if($SECOND_PERSON)
{                    say("You have stored ");}
                else
{                    say("I've stored ");}
                say("$n treasures.  On a scale of 0 to 100, that rates ");
                say(($n*100)/$GameHeader{Treasures});
                if($n==$GameHeader{Treasures})
                {
                    say("Well done.\n");
                    goto doneit;
                }
            }
            }
            when (66) {
            {
                my $ct=0;
                my $f=0;
                if($SECOND_PERSON)
{                    say("You are carrying:\n");}
                else
{                    say("I'm carrying:\n");}
                while($ct<=$GameHeader{NumItems})
                {
                    if($Items[$ct]{Location}==CARRIED)
                    {
                        if($f==1)
                        {
                            if ($TRS80_STYLE) {
                                say(". "); }
                            else {
                                say(" - "); }
                        }
                        $f=1;
                        say($Items[$ct]{Text});
                    }
                    $ct++;
                }
                if($f==0)
{                    say("Nothing");}
            }
            }
            when (67) {
                $BitFlags|=(1<<0);
            }
            when (68) {
                $BitFlags&=~(1<<0);
            }
            when (69) {
                $GameHeader{LightTime}=$LightRefill;
                if($Items[LIGHT_SOURCE]{Location}==MyLoc)
                  {  $Redraw=1; }
                $Items[LIGHT_SOURCE]{Location}=CARRIED;
                $BitFlags&=~(1<<LIGHTOUTBIT);
            }
            when (70) {
                #ClearScreen(); #  pdd.
                #OutReset();
            }
            when (71) {
                SaveGame();
            }
            when (72) {
            {
                my $i1=$param[$pptr++];
                my $i2=$param[$pptr++];
                my $t=$Items[$i1]{Location};
                if($t==MyLoc || $Items[$i2]{Location}==MyLoc)
{                    $Redraw=1;}
                $Items[$i1]{Location}=$Items[$i2]{Location};
                $Items[$i2]{Location}=$t;
            }
            }
            when (73) {
                $continuation=1;
            }
            when (74) {
                if($Items[$param[$pptr]]{Location}==MyLoc)
{                    $Redraw=1;}
                $Items[$param[$pptr++]]{Location}= CARRIED;
            }
            when (75) {
            {
                my $i1=$param[$pptr++];
                my $i2=$param[$pptr++];
                if($Items[$i1]{Location}==MyLoc)
{                    $Redraw=1;}
                $Items[$i1]{Location}=$Items[$i2]{Location};
                if($Items[$i2]{Location}==MyLoc)
{                    $Redraw=1;}
            }
            }
            when (76) {    #  Looking at adventure ..
                say Look();
            }
            when (77) {
                if($CurrentCounter>=0)
{                    $CurrentCounter--;}
            }
            when (78) {
                say($CurrentCounter);
            }
            when (79) {
                $CurrentCounter=$param[$pptr++];
            }
            when (80) {
            {
                my $t=MyLoc;
                $GameHeader{PlayerRoom}=$SavedRoom;
                $SavedRoom=$t;
                $Redraw=1;
            }
            }
            when (81) {
            {
                # This is somewhat guessed. Claymorgue always
                # seems to do select counter n, thing, select counter n,
                # but uses one value that always seems to exist. Trying
                # a few options I found this gave sane results on ageing
                my $t=$param[$pptr++];
                my $c1=$CurrentCounter;
                $CurrentCounter=$Counters[$t];
                $Counters[$t]=$c1;
            }
            }
            when (82) {
                $CurrentCounter+=$param[$pptr++];
            }
            when (83) {
                $CurrentCounter-=$param[$pptr++];
                if($CurrentCounter< -1)
{                    $CurrentCounter= -1;}
                # Note: This seems to be needed. I don't yet
                # know if there is a maximum value to limit too
            }
            when (84) {
                say($NounText);
            }
            when (85) {
                say($NounText);
                say("\n");
            }
            when (86) {
                say("\n");
            }
            when (87) {
            {
                # Changed this to swap location<->roomflag[x]
                # not roomflag 0 and x
                my $p=$param[$pptr++];
                my $sr=MyLoc;
                $GameHeader{PlayerRoom} = $RoomSaved[$p];
                $RoomSaved[$p]=$sr;
                $Redraw=1;
            }
            }
            when (88) {
                #wrefresh(Top);
                #wrefresh(Bottom);
                sleep(2);    #  DOC's say 2 seconds. Spectrum times at 1.5
            }
            when (89) {
                $pptr++;
                #  SAGA draw picture n
                #  Spectrum Seas of Blood - start combat ?
                #  Poking this into older spectrum games causes a crash
            }
            default:
                warn(sprintf "Unknown action %d [Param begins %d %d]\n",
                    $act[$cc],$param[$pptr],$param[$pptr+1]);
            }
        }
        $cc++;
    }
    return(1+$continuation);
}

sub PerformActions {
    my ( $vb, $no ) = @_;

    state $disable_sysfunc = 0;    # recursion lock?
    my $d = $BitFlags & ( 1 << DARKBIT );

    if ( $vb == 1 && !defined $no ) {
        say("Give me a direction too.");
        return 0;
    }
    if ( $vb == 1 && $no >= 1 && $no <= 6 ) {
        my $nl;
        if (   $Items[LIGHT_SOURCE]{Location} == MyLoc
            || $Items[LIGHT_SOURCE]{Location} == CARRIED )
        {
            $d = 0;
        }
        if ($d) {
            say("Dangerous to move in the dark! ");
        }
        $nl = $Rooms[MyLoc]{Exits}[ $no - 1 ];

        if ( $nl != 0 ) {
            $GameHeader{PlayerRoom} = $nl;
            say Look();
            return 0;
        }
        if ($d) {
            if ($SECOND_PERSON) {
                say("You fell down and broke your neck. ");
            }
            else {
                say("I fell down and broke my neck. ");
            }
            sleep(5);
            exit(0);
        }
        if ($SECOND_PERSON) {
            say("You can't go in that direction. ");
        }
        else {
            say("I can't go in that direction. ");
        }
        return 0;
    }
    my $ct      = 0;
    my $fl      = -1;
    my $doagain = 0;
    ACTIONS: foreach my $ct ( 0 .. $GameHeader{NumActions} ) {
        my ( $vv, $nv );
        $vv = $Actions[$ct]{Vocab};

        #/* Think this is now right. If a line we run has an action73
        #   run all following lines with vocab of 0,0 */
        if ( $vb != 0 && ( $doagain && $vv != 0 ) ) {
            last ACTIONS;
        }

        ##  Oops.. added this minor cockup fix 1.11
        if ( $vb != 0 && !$doagain && $fl == 0 ) {
            last ACTIONS;
        }
        $nv = $vv % 150;
        $vv /= 150;
        if ( ( $vv == $vb ) || ( $doagain && $Actions[$ct]{Vocab} == 0 ) ) {
            if (   ( $vv == 0 && RandomPercent($nv) )
                || $doagain
                || ( $vv != 0 && ( $nv == ( $no // -666 ) || $nv == 0 ) ) )
            {
                my $f2;
                if ( $fl == -1 ) { $fl = -2 }
                if ( ( $f2 = PerformLine($ct) ) > 0 ) {

                    ##  ahah finally figured it out !
                    $fl = 0;
                    if ( $f2 == 2 ) {
                        $doagain = 1;
                    }
                    if ( $vb != 0 && $doagain == 0 ) {
                        return;
                    }
                }
            }
        }
        if ( $Actions[$ct]{Vocab} != 0 ) {
            $doagain = 0;
        }
    }
    if ( $fl != 0 && $disable_sysfunc == 0 ) {
        my $i;
        if (   $Items[LIGHT_SOURCE]{Location} == MyLoc
            || $Items[LIGHT_SOURCE]{Location} == CARRIED )
        {
            $d = 0;
        }
        if ( $vb == GET || $vb == DROP ) {

            # Yes they really _are_ hardcoded values
            if ( $vb == GET ) {
                if ( strncasecmp( $NounText, "ALL", $GameHeader{WordLength} ) ) {
                    my $f = 0;
                    if ($d) {
                        say("It is dark.\n");
                        return 0;
                    }
                    for my $ct ( 0 .. $GameHeader{NumItems} ) {
                        if (   $Items[$ct]{Location} == MyLoc
                            && defined $Items[$ct]{AutoGet}
                            && $Items[$ct]{AutoGet} !~ /^\*/ )
                        {
                            $no = WhichWord( $Items[$ct]{AutoGet}, \@Nouns );
                            $disable_sysfunc = 1;    #  Don't recurse into auto get !
                            PerformActions( $vb, $no );    #  Recursively check each items table code
                            $disable_sysfunc = 0;
                            if ( CountCarried() == $GameHeader{MaxCarry} ) {
                                if ($SECOND_PERSON) {
                                    say("You are carrying too much. ");
                                }
                                else {
                                    say("I've too much to carry. ");
                                }
                                return (0);
                            }
                            $Items[$ct]{Location} = CARRIED;
                            say( $Items[$ct]{Text} .": O.K.");
                            $f = 1;
                        }
                    }
                    if ( $f == 0 ) {
                        say("Nothing taken.");
                    }
                    return (0);
                }
                if ( not defined $no ) {
                    say("What ? ");
                    return (0);
                }
                if ( CountCarried() == $GameHeader{MaxCarry} ) {
                    if ($SECOND_PERSON) {
                        say("You are carrying too much. ");
                    }
                    else {
                        say("I've too much to carry. ");
                    }
                    return (0);
                }
                my $i = MatchUpItem( $NounText, MyLoc );
                if ( not defined $i ) {
                    if ($SECOND_PERSON) {
                        say("It is beyond your power to do that. ");
                    }
                    else {
                        say("It's beyond my power to do that. ");
                    }
                    return (0);
                }
                $Items[$i]{Location} = CARRIED;
                say("O.K. ");
                return (0);
            }
            if ( $vb == DROP ) {
                if ( strncasecmp( $NounText, "ALL", $GameHeader{WordLength} ) ) {
                    my $f = 0;
                    foreach my $ct ( 0 .. $GameHeader{NumItems} ) {
                        if (   $Items[$ct]{Location} == CARRIED
                            && $Items[$ct]{AutoGet}
                            && $Items[$ct]{AutoGet} !~ /^\*/ )
                        {
                            $no = WhichWord( $Items[$ct]{AutoGet}, \@Nouns );
                            $disable_sysfunc = 1;
                            PerformActions( $vb, $no );
                            $disable_sysfunc = 0;
                            $Items[$ct]{Location} = MyLoc;
                            say( $Items[$ct]{Text} . ": O.K.\n" );
                            $f = 1;
                        }
                    }
                    if ( $f == 0 ) {
                        say("Nothing dropped.\n");
                    }
                    return (0);
                }
                if ( !defined $no ) {
                    say("What ? ");
                    return (0);
                }
                $i = MatchUpItem( $NounText, CARRIED );
                if ( not defined $i ) {
                    if ($SECOND_PERSON) {
                        say("It's beyond your power to do that.\n");
                    }
                    else {
                        say("It's beyond my power to do that.\n");
                    }
                    return (0);
                }
                $Items[$i]{Location} = MyLoc;
                say("O.K. ");
                return (0);
            }
        }
    }
    return ($fl);
}

sub main {

    #FILE *f;
    #int vb,no;

    GetOptions(
        i => sub { $SECOND_PERSON = 0 },
        d => \$DEBUGGING,
        s => \$SCOTTLIGHT,
        t => \$TRS80_STYLE,
        p => \$PREHISTORIC_LAMP,
        h => sub {
            say("$0 [-h] [-y] [-s] [-i] [-t] [-d] [-p] <gamename> [savedgame].");
            exit;
        },
    );
    $ARGV[0] //= 'adv00';    # XXX remove
    if ( !@ARGV ) {
        warn "$0 <database> <savefile>.\n";
        exit(1);
    }
    if ($TRS80_STYLE) {
        $Width        = 64;
        $TopHeight    = 11;
        $BottomHeight = 13;
    }
    else {
        $Width        = 80;
        $TopHeight    = 10;
        $BottomHeight = 14;
    }
    say <<"END";
Scott Free, A Scott Adams game driver in C.\n\
Release 1.14, (c) 1993,1994,1995 Swansea University Computer Society.\n\
Distributed under the GNU software license

END
    LoadDatabase( $ARGV[0], $DEBUGGING );

    #    if(argc==3)
    #        LoadGame(argv[2]);

    say Look();
    while (1) {

        #        if(Redraw!=0)
        #        {
        #            say Look();
        #            Redraw=0;
        #        }
        PerformActions( 0, 0 );
        #        if(Redraw!=0)
        #        {
        #            say Look();
        #            Redraw=0;
        #        }
        my ( $verb, $noun ) = GetInput();
        given ( PerformActions( $verb, $noun ) ) {
            when (-1) { say("I don't understand your command. ") }
            when (-2) { say("I can't do that yet. ") }
        }

        #        #  Brian Howarth games seem to use -1 for forever
        #        if($Items[LIGHT_SOURCE]{Location}# ==-1!=DESTROYED && $GameHeader{LightTime}!= -1)
        #        {
        #            $GameHeader{LightTime}--;
        #            if($GameHeader{LightTime}<1)
        #            {
        #                BitFlags|=(1<<LIGHTOUTBIT);
        #                if($Items[LIGHT_SOURCE]{Location}==CARRIED ||
        #                    $Items[LIGHT_SOURCE]{Location}==MyLoc)
        #                {
        #                    if($SCOTTLIGHT)
        #                        say("Light has run out! ");
        #                    else
        #                        say("Your light has run out. ");
        #                }
        #                if(Options&PREHISTORIC_LAMP)
        #                    $Items[LIGHT_SOURCE]{Location}=DESTROYED;
        #            }
        #            else if($GameHeader{LightTime}<25)
        #            {
        #                if($Items[LIGHT_SOURCE]{Location}==CARRIED ||
        #                    $Items[LIGHT_SOURCE]{Location}==MyLoc)
        #                {
        #
        #                    if($SCOTTLIGHT)
        #                    {
        #                        say("Light runs out in ");
        #                        sayNumber($GameHeader{LightTime});
        #                        say(" turns. ");
        #                    }
        #                    else
        #                    {
        #                        if($GameHeader{LightTime}%5==0)
        #                            say("Your light is growing dim. ");
        #                    }
        #                }
        #            }
        #        }
    }
}
main() unless caller;

sub _get_int {
    my $fh = shift;
    chomp( my $int = <$fh> );
    $int =~ s/^\s+|\s+$//g;
    unless ( $int =~ /^[0-9]+$/ && $int >= 0 ) {
        croak("Read '$int' from database. Need an int");
    }
    return $int;
}

sub ReadString {
    my $fh = shift;
    chomp( my $word = <$fh> );
    if ( $word eq '"' ) {

        # This handles the case where a quoted multi-line string might start
        # with a single quote on a line by itself.
        chomp( $word .= <$fh> );
    }
    while ( $word !~ /"$/ ) {
        chomp( $word .= "\n" . <$fh> );
    }
    $word =~ s/^"|"$//g;
    return $word;
}

sub ReadItem {
    my $fh = shift;
    chomp( my $line = <$fh> );

    my ( $item, $location, $autoget );

    ( $item, $location ) = ( $line =~ /^"(.*)"\s+([0-9]+)\s*$/ );
    unless ( defined $item and defined $location ) {
        croak("Bad item read at data file line $.: $line");
    }

    if ( $item =~ s!/([^/]+)/$!! ) {
        $autoget = $1;
    }
    return $item, $location, $autoget;
}

sub LoadDatabase {
    my ( $db, $loud ) = @_;
    open my $fh, '<', $db;

    my @headers = qw(
      Unknown1
      NumItems  NumActions  NumWords     NumRooms
      MaxCarry  PlayerRoom  Treasures    WordLength
      LightTime NumMessages TreasureRoom
    );
    foreach my $header (@headers) {
        $GameHeader{$header} = _get_int($fh);
    }

    $LightRefill = $GameHeader{LightTime};

    for my $i ( 0 .. $GameHeader{NumActions} ) {
        my %action = (
            Vocab     => _get_int($fh),
            Condition => [],
            Action    => [],
        );
        for ( 1 .. 5 ) {
            push @{ $action{Condition} } => _get_int($fh);
        }
        $action{Action}[0] = _get_int($fh);
        $action{Action}[1] = _get_int($fh);
        push @Actions => \%action;
    }
    if (0) {
        print Dumper( $GameHeader{NumActions}, $Actions[-1] );
        print <<'END';
NumActions: 169
Action0:    8176
Action1:    0
Condition0: 584
Condition1: 600
Condition2: 0
Condition3: 0
Condition4: 0
Vocab:      166
END
        exit;
    }

    for ( 0 .. $GameHeader{NumWords} ) {
        push @Verbs => ReadString($fh);
        push @Nouns => ReadString($fh);
    }
    if (0) {
        print Dumper( $Verbs[-1], $Nouns[-1] );
        print <<'END';
Last verb: OPE
Last noun: YOH
END
        exit;
    }

    foreach ( 0 .. $GameHeader{NumRooms} ) {
        my %room = (
            Text  => undef,
            Exits => [],
        );
        for ( 1 .. 6 ) {
            push @{ $room{Exits} } => _get_int($fh);
        }
        $room{Text} = ReadString($fh);
        push @Rooms => \%room;
    }
    if (0) {
        print Dumper( $Rooms[-1] );
        print <<'END';
large misty room with strange
unreadable letters over all the exits.
END
        exit;
    }

    for ( 0 .. $GameHeader{NumMessages} ) {    # XXX what happened here?
        push @Messages => ReadString($fh);
    }
    if (0) {
        print Dumper( $GameHeader{NumMessages}, $Messages[-1], $. );
        exit;
    }

    for ( 0 .. $GameHeader{NumItems} ) {
        my ( $item, $location, $autoget ) = ReadItem($fh);
        push @Items => {
            Text       => $item,
            Location   => $location,
            InitialLoc => $location,
            AutoGet    => $autoget,
        };
    }

    ReadString($fh) for 0 .. $GameHeader{NumActions};    # skip comment strings

    my $version = _get_int($fh);
    printf(
        "Version %d.%02d of Adventure \n\n",
        $version / 100, $version % 100
    );
}

sub Look {
    my @ExitNames = qw(North South East West Up Down);

    my $look = '';
    my $r    = $Rooms[MyLoc];

    if (   ( $BitFlags & ( 1 << DARKBIT ) )
        && $Items[LIGHT_SOURCE]{Location} != CARRIED
        && $Items[LIGHT_SOURCE]{Location} != MyLoc )
    {
        if ($SECOND_PERSON) {
            return ("You can't see. It is too dark!");
        }
        else {
            return ("I can't see. It is too dark!");
        }
    }
    my $text = $r->{Text};
    if ( $text =~ s/^\*// ) {    # XXX ???
        $look .= $text;
    }
    else {
        if ($SECOND_PERSON) {
            $look .= "You are in a $text\n";
        }
        else {
            $look .= "I'm in a $text\n";
        }
    }
    $look .= "\n";

    my $f = 0;
    $look .= "\nObvious exits:\n";
    foreach ( 0 .. 5 ) {
        if ( $r->{Exits}[$_] ) {
            if ( !$f ) {
                $f = 1;
            }
            else {
                $look .= ", ";
            }
            $look .= $ExitNames[$_];
        }
    }

    if ( !$f ) {
        $look .= "none\n";
    }
    else {
        $look .= "\n\n";
    }

    $f = 0;
    my $pos = 0;

    foreach my $i ( 0 .. $GameHeader{NumItems} ) {
        if ( $Items[$i]{Location} == MyLoc ) {
            if ( !$f ) {
                $look .=
                  $SECOND_PERSON
                  ? "You can also see:\n"
                  : "I can also see:\n";
                $pos = 16;
                $f++;
            }
            else {
                $look .= "\n";
            }
            $look .= "  - " . $Items[$i]{Text};
        }
    }
    return $look;
}
