#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;
use Getopt::Long;
use autodie ':all';
use Carp 'croak';
use Storable 'dclone';

use Data::Dumper::Simple;
local $Data::Dumper::Indent   = 1;
local $Data::Dumper::Sortkeys = 1;
 
use constant LIGHT_SOURCE => 9;   # /* Always 9 how odd */
use constant CARRIED      => 255; # /* Carried */
use constant DESTROYED    => 0;   # /* Destroyed */
use constant DARKBIT      => 1;   #
use constant LIGHTOUTBIT  => 16;  # /* Light gone out */

my $SECOND_PERSON    = 1;    # "you are" instead of "I am";
my $SCOTTLIGHT       = 0;    #	/* Authentic Scott Adams light messages */
my $DEBUGGING        = 0;    #	/* Info from database load */
my $TRS80_STYLE      = 0;    #	/* Display in style used on TRS-80 */
my $PREHISTORIC_LAMP = 1;    #	/* Destroy the lamp (very old databases) */
 
#     NumWords        /* Smaller of verb/noun is padded to same size */
my %GameHeader = map { $_ => 0 } qw(
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

my @Actions;

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
#sub strncasecmp {
#    my ( $word1, $word2 ) = @_;
#    return lc($word1) eq lc($word2);
#}
#sub getpid {$$}
#
#Tail GameTail;
my @Items;
my @Rooms;
my @Verbs;
my @Nouns;
my @Messages;
#Action *Actions;
my $LightRefill;
#char NounText[16];
#int Counters[16];    /* Range unknown */
#int CurrentCounter;
#int SavedRoom;
#int RoomSaved[16];    /* Range unknown */
#int DisplayUp;        /* Curses up */
#WINDOW *Top,*Bottom;
#int Redraw;        /* Update item window */
my $Options = 0;   #     /* Option flags set */
my $Width; #       /* Terminal width */
my $TopHeight; #       /* Height of top window */
my $BottomHeight; #   /* Height of bottom window */
#
use constant TRS80_LINE =>
  "\n<------------------------------------------------------------>\n";
#
sub MyLoc { $GameHeader{PlayerRoom} }
#
my $BitFlags = 0;  #   /* Might be >32 flags - I haven't seen >32 yet */
#
#void Fatal(char *x)
#{
#    if(DisplayUp)
#        endwin();
#    fprintf(stderr,"%s.\n",x);
#    exit(1);
#}
#
#void Aborted()
#{
#    Fatal("User exit");
#}
#
#void ClearScreen(void)
#{
#    werase(Bottom);
#    wrefresh(Bottom);
#}
#
#void *MemAlloc(int size)
#{
#    void *t=(void *)malloc(size);
#    if(t==NULL)
#        Fatal("Out of memory");
#    return(t);
#}
#
#int RandomPercent(int n)
#{
#    unsigned int rv=rand()<<6;
#    rv%=100;
#    if(rv<n)
#        return(1);
#    return(0);
#}
#
#int CountCarried()
#{
#    int ct=0;
#    int n=0;
#    while(ct<=$GameHeader{NumItems})
#    {
#        if(Items[ct].Location==CARRIED)
#            n++;
#        ct++;
#    }
#    return(n);
#}
#
#char *MapSynonym(char *word)
#{
#    int n=1;
#    char *tp;
#    static char lastword[16];    /* Last non synonym */
#    while(n<=$GameHeader{NumWords})
#    {
#        tp=Nouns[n];
#        if(*tp=='*')
#            tp++;
#        else
#            strcpy(lastword,tp);
#        if(strncasecmp(word,tp,$GameHeader{WordLength})==0)
#            return(lastword);
#        n++;
#    }
#    return(NULL);
#}
#
#int MatchUpItem(char *text, int loc)
#{
#    char *word=MapSynonym(text);
#    int ct=0;
#
#    if(word==NULL)
#        word=text;
#
#    while(ct<=$GameHeader{NumItems})
#    {
#        if(Items[ct].AutoGet && Items[ct].Location==loc &&
#            strncasecmp(word,tp,$GameHeader{WordLength})==0)
#            return(n);
#        ne++;
#    }
#    return(-1);
#}
#
#
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
#void GetInput(vb,no)
#int *vb,*no;
#{
#    char buf[256];
#    char verb[10],noun[10];
#    int vc,nc;
#    int num;
#    do
#    {
#        do
#        {
#            Output("\nTell me what to do ? ");
#            wrefresh(Bottom);
#            LineInput(buf);
#            OutReset();
#            num=sscanf(buf,"%9s %9s",verb,noun);
#        }
#        while(num==0||*buf=='\n');
#        if(num==1)
#            *noun=0;
#        if(*noun==0 && strlen(verb)==1)
#        {
#            switch(isupper(*verb)?tolower(*verb):*verb)
#            {
#                case 'n':strcpy(verb,"NORTH");break;
#                case 'e':strcpy(verb,"EAST");break;
#                case 's':strcpy(verb,"SOUTH");break;
#                case 'w':strcpy(verb,"WEST");break;
#                case 'u':strcpy(verb,"UP");break;
#                case 'd':strcpy(verb,"DOWN");break;
#                /* Brian Howarth interpreter also supports this */
#                case 'i':strcpy(verb,"INVENTORY");break;
#            }
#        }
#        nc=WhichWord(verb,Nouns);
#        /* The Scott Adams system has a hack to avoid typing 'go' */
#        if(nc>=1 && nc <=6)
#        {
#            vc=1;
#        }
#        else
#        {
#            vc=WhichWord(verb,Verbs);
#            nc=WhichWord(noun,Nouns);
#        }
#        *vb=vc;
#        *no=nc;
#        if(vc==-1)
#        {
#            Output("You use word(s) I don't know! ");
#        }
#    }
#    while(vc==-1);
#    strcpy(NounText,noun);    /* Needed by GET/DROP hack */
#}
#
#void SaveGame()
#{
#    char buf[256];
#    int ct;
#    FILE *f;
#    Output("Filename: ");
#    LineInput(buf);
#    Output("\n");
#    f=fopen(buf,"w");
#    if(f==NULL)
#    {
#        Output("Unable to create save file.\n");
#        return;
#    }
#    for(ct=0;ct<16;ct++)
#    {
#        fprintf(f,"%d %d\n",Counters[ct],RoomSaved[ct]);
#    }
#    fprintf(f,"%ld %d %hd %d %d %hd\n",BitFlags, (BitFlags&(1<<DARKBIT))?1:0,
#        MyLoc,CurrentCounter,SavedRoom,$GameHeader{LightTime});
#    for(ct=0;ct<=$GameHeader{NumItems};ct++)
#        fprintf(f,"%hd\n",(short)Items[ct].Location);
#    fclose(f);
#    Output("Saved.\n");
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
#        Output("Unable to restore game.");
#        return;
#    }
#    for(ct=0;ct<16;ct++)
#    {
#        fscanf(f,"%d %d\n",&Counters[ct],&RoomSaved[ct]);
#    }
#    fscanf(f,"%ld %d %hd %d %d %hd\n",
#        &BitFlags,&DarkFlag,&MyLoc,&CurrentCounter,&SavedRoom,
#        &$GameHeader{LightTime});
#    /* Backward compatibility */
#    if(DarkFlag)
#        BitFlags|=(1<<15);
#    for(ct=0;ct<=$GameHeader{NumItems};ct++)
#    {
#        fscanf(f,"%hd\n",&lo);
#        Items[ct].Location=(unsigned char)lo;
#    }
#    fclose(f);
#}
#
#int PerformLine(int ct)
#{
#    int continuation=0;
#    int param[5],pptr=0;
#    int act[4];
#    int cc=0;
#    while(cc<5)
#    {
#        int cv,dv;
#        cv=Actions[ct].Condition[cc];
#        dv=cv/20;
#        cv%=20;
#        switch(cv)
#        {
#            case 0:
#                param[pptr++]=dv;
#                break;
#            case 1:
#                if(Items[dv].Location!=CARRIED)
#                    return(0);
#                break;
#            case 2:
#                if(Items[dv].Location!=MyLoc)
#                    return(0);
#                break;
#            case 3:
#                if(Items[dv].Location!=CARRIED&&
#                    Items[dv].Location!=MyLoc)
#                    return(0);
#                break;
#            case 4:
#                if(MyLoc!=dv)
#                    return(0);
#                break;
#            case 5:
#                if(Items[dv].Location==MyLoc)
#                    return(0);
#                break;
#            case 6:
#                if(Items[dv].Location==CARRIED)
#                    return(0);
#                break;
#            case 7:
#                if(MyLoc==dv)
#                    return(0);
#                break;
#            case 8:
#                if((BitFlags&(1<<dv))==0)
#                    return(0);
#                break;
#            case 9:
#                if(BitFlags&(1<<dv))
#                    return(0);
#                break;
#            case 10:
#                if(CountCarried()==0)
#                    return(0);
#                break;
#            case 11:
#                if(CountCarried())
#                    return(0);
#                break;
#            case 12:
#                if(Items[dv].Location==CARRIED||Items[dv].Location==MyLoc)
#                    return(0);
#                break;
#            case 13:
#                if(Items[dv].Location==0)
#                    return(0);
#                break;
#            case 14:
#                if(Items[dv].Location)
#                    return(0);
#                break;
#            case 15:
#                if(CurrentCounter>dv)
#                    return(0);
#                break;
#            case 16:
#                if(CurrentCounter<=dv)
#                    return(0);
#                break;
#            case 17:
#                if(Items[dv].Location!=Items[dv].InitialLoc)
#                    return(0);
#                break;
#            case 18:
#                if(Items[dv].Location==Items[dv].InitialLoc)
#                    return(0);
#                break;
#            case 19:/* Only seen in Brian Howarth games so far */
#                if(CurrentCounter!=dv)
#                    return(0);
#                break;
#        }
#        cc++;
#    }
#    /* Actions */
#    act[0]=Actions[ct].Action[0];
#    act[2]=Actions[ct].Action[1];
#    act[1]=act[0]%150;
#    act[3]=act[2]%150;
#    act[0]/=150;
#    act[2]/=150;
#    cc=0;
#    pptr=0;
#    while(cc<4)
#    {
#        if(act[cc]>=1 && act[cc]<52)
#        {
#            Output(Messages[act[cc]]);
#            Output("\n");
#        }
#        else if(act[cc]>101)
#        {
#            Output(Messages[act[cc]-50]);
#            Output("\n");
#        }
#        else switch(act[cc])
#        {
#            case 0:/* NOP */
#                break;
#            case 52:
#                if(CountCarried()==$GameHeader{MaxCarry})
#                {
#                    if($SECOND_PERSON)
#                        Output("You are carrying too much. ");
#                    else
#                        Output("I've too much to carry! ");
#                    break;
#                }
#                if(Items[param[pptr]].Location==MyLoc)
#                    Redraw=1;
#                Items[param[pptr++]].Location= CARRIED;
#                break;
#            case 53:
#                Redraw=1;
#                Items[param[pptr++]].Location=MyLoc;
#                break;
#            case 54:
#                Redraw=1;
#                MyLoc=param[pptr++];
#                break;
#            case 55:
#                if(Items[param[pptr]].Location==MyLoc)
#                    Redraw=1;
#                Items[param[pptr++]].Location=0;
#                break;
#            case 56:
#                BitFlags|=1<<DARKBIT;
#                break;
#            case 57:
#                BitFlags&=~(1<<DARKBIT);
#                break;
#            case 58:
#                BitFlags|=(1<<param[pptr++]);
#                break;
#            case 59:
#                if(Items[param[pptr]].Location==MyLoc)
#                    Redraw=1;
#                Items[param[pptr++]].Location=0;
#                break;
#            case 60:
#                BitFlags&=~(1<<param[pptr++]);
#                break;
#            case 61:
#                if($SECOND_PERSON)
#                    Output("You are dead.\n");
#                else
#                    Output("I am dead.\n");
#                BitFlags&=~(1<<DARKBIT);
#                MyLoc=$GameHeader{NumRooms};/* It seems to be what the code says! */
#                Look();
#                break;
#            case 62:
#            {
#                /* Bug fix for some systems - before it could get parameters wrong */
#                int i=param[pptr++];
#                Items[i].Location=param[pptr++];
#                Redraw=1;
#                break;
#            }
#            case 63:
#doneit:                Output("The game is now over.\n");
#                wrefresh(Bottom);
#                sleep(5);
#                endwin();
#                exit(0);
#            case 64:
#                Look();
#                break;
#            case 65:
#            {
#                int ct=0;
#                int n=0;
#                while(ct<=$GameHeader{NumItems})
#                {
#                    if(Items[ct].Location==$GameHeader{TreasureRoom} &&
#                      *Items[ct].Text=='*')
#                          n++;
#                    ct++;
#                }
#                if($SECOND_PERSON)
#                    Output("You have stored ");
#                else
#                    Output("I've stored ");
#                OutputNumber(n);
#                Output(" treasures.  On a scale of 0 to 100, that rates ");
#                OutputNumber((n*100)/$GameHeader{Treasures});
#                Output(".\n");
#                if(n==$GameHeader{Treasures})
#                {
#                    Output("Well done.\n");
#                    goto doneit;
#                }
#                break;
#            }
#            case 66:
#            {
#                int ct=0;
#                int f=0;
#                if($SECOND_PERSON)
#                    Output("You are carrying:\n");
#                else
#                    Output("I'm carrying:\n");
#                while(ct<=$GameHeader{NumItems})
#                {
#                    if(Items[ct].Location==CARRIED)
#                    {
#                        if(f==1)
#                        {
#                            if ($TRS80_STYLE)
#                                Output(". ");
#                            else
#                                Output(" - ");
#                        }
#                        f=1;
#                        Output(Items[ct].Text);
#                    }
#                    ct++;
#                }
#                if(f==0)
#                    Output("Nothing");
#                Output(".\n");
#                break;
#            }
#            case 67:
#                BitFlags|=(1<<0);
#                break;
#            case 68:
#                BitFlags&=~(1<<0);
#                break;
#            case 69:
#                $GameHeader{LightTime}=LightRefill;
#                if($Items[LIGHT_SOURCE]{Location}==MyLoc)
#                    Redraw=1;
#                $Items[LIGHT_SOURCE]{Location}=CARRIED;
#                BitFlags&=~(1<<LIGHTOUTBIT);
#                break;
#            case 70:
#                ClearScreen(); /* pdd. */
#                OutReset();
#                break;
#            case 71:
#                SaveGame();
#                break;
#            case 72:
#            {
#                int i1=param[pptr++];
#                int i2=param[pptr++];
#                int t=Items[i1].Location;
#                if(t==MyLoc || Items[i2].Location==MyLoc)
#                    Redraw=1;
#                Items[i1].Location=Items[i2].Location;
#                Items[i2].Location=t;
#                break;
#            }
#            case 73:
#                continuation=1;
#                break;
#            case 74:
#                if(Items[param[pptr]].Location==MyLoc)
#                    Redraw=1;
#                Items[param[pptr++]].Location= CARRIED;
#                break;
#            case 75:
#            {
#                int i1,i2;
#                i1=param[pptr++];
#                i2=param[pptr++];
#                if(Items[i1].Location==MyLoc)
#                    Redraw=1;
#                Items[i1].Location=Items[i2].Location;
#                if(Items[i2].Location==MyLoc)
#                    Redraw=1;
#                break;
#            }
#            case 76:    /* Looking at adventure .. */
#                Look();
#                break;
#            case 77:
#                if(CurrentCounter>=0)
#                    CurrentCounter--;
#                break;
#            case 78:
#                OutputNumber(CurrentCounter);
#                break;
#            case 79:
#                CurrentCounter=param[pptr++];
#                break;
#            case 80:
#            {
#                int t=MyLoc;
#                MyLoc=SavedRoom;
#                SavedRoom=t;
#                Redraw=1;
#                break;
#            }
#            case 81:
#            {
#                /* This is somewhat guessed. Claymorgue always
#                   seems to do select counter n, thing, select counter n,
#                   but uses one value that always seems to exist. Trying
#                   a few options I found this gave sane results on ageing */
#                int t=param[pptr++];
#                int c1=CurrentCounter;
#                CurrentCounter=Counters[t];
#                Counters[t]=c1;
#                break;
#            }
#            case 82:
#                CurrentCounter+=param[pptr++];
#                break;
#            case 83:
#                CurrentCounter-=param[pptr++];
#                if(CurrentCounter< -1)
#                    CurrentCounter= -1;
#                /* Note: This seems to be needed. I don't yet
#                   know if there is a maximum value to limit too */
#                break;
#            case 84:
#                Output(NounText);
#                break;
#            case 85:
#                Output(NounText);
#                Output("\n");
#                break;
#            case 86:
#                Output("\n");
#                break;
#            case 87:
#            {
#                /* Changed this to swap location<->roomflag[x]
#                   not roomflag 0 and x */
#                int p=param[pptr++];
#                int sr=MyLoc;
#                MyLoc=RoomSaved[p];
#                RoomSaved[p]=sr;
#                Redraw=1;
#                break;
#            }
#            case 88:
#                wrefresh(Top);
#                wrefresh(Bottom);
#                sleep(2);    /* DOC's say 2 seconds. Spectrum times at 1.5 */
#                break;
#            case 89:
#                pptr++;
#                /* SAGA draw picture n */
#                /* Spectrum Seas of Blood - start combat ? */
#                /* Poking this into older spectrum games causes a crash */
#                break;
#            default:
#                fprintf(stderr,"Unknown action %d [Param begins %d %d]\n",
#                    act[cc],param[pptr],param[pptr+1]);
#                break;
#        }
#        cc++;
#    }
#    return(1+continuation);        
#}
#
#
sub PerformActions {
    my ( $vb, $no ) = @_;

    state $disable_sysfunc = 0; # recursion lock?
    my $d = $BitFlags&(1<<DARKBIT);

    my $ct = 0;
    my $fl;
    my $doagain = 0;
    if($vb==1 && $no == -1 )
    {
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
            Look();
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
#    fl= -1;
#    while(ct<=$GameHeader{NumActions})
#    {
#        int vv,nv;
#        vv=Actions[ct].Vocab;
#        /* Think this is now right. If a line we run has an action73
#           run all following lines with vocab of 0,0 */
#        if(vb!=0 && (doagain&&vv!=0))
#            break;
#        /* Oops.. added this minor cockup fix 1.11 */
#        if(vb!=0 && !doagain && fl== 0)
#            break;
#        nv=vv%150;
#        vv/=150;
#        if((vv==vb)||(doagain&&Actions[ct].Vocab==0))
#        {
#            if((vv==0 && RandomPercent(nv))||doagain||
#                (vv!=0 && (nv==no||nv==0)))
#            {
#                int f2;
#                if(fl== -1)
#                    fl= -2;
#                if((f2=PerformLine(ct))>0)
#                {
#                    /* ahah finally figured it out ! */
#                    fl=0;
#                    if(f2==2)
#                        doagain=1;
#                    if(vb!=0 && doagain==0)
#                        return;
#                }
#            }
#        }
#        ct++;
#        if(Actions[ct].Vocab!=0)
#            doagain=0;
#    }
#    if(fl!=0 && disable_sysfunc==0)
#    {
#        int i;
#        if($Items[LIGHT_SOURCE]{Location}==MyLoc ||
#           $Items[LIGHT_SOURCE]{Location}==CARRIED)
#               d=0;
#        if(vb==10 || vb==18)
#        {
#            /* Yes they really _are_ hardcoded values */
#            if(vb==10)
#            {
#                if(strcasecmp(NounText,"ALL")==0)
#                {
#                    int ct=0;
#                    int f=0;
#                    
#                    if(d)
#                    {
#                        Output("It is dark.\n");
#                        return 0;
#                    }
#                    while(ct<=$GameHeader{NumItems})
#                    {
#                        if(Items[ct].Location==MyLoc && Items[ct].AutoGet!=NULL && Items[ct].AutoGet[0]!='*')
#                        {
#                            no=WhichWord(Items[ct].AutoGet,Nouns);
#                            disable_sysfunc=1;    /* Don't recurse into auto get ! */
#                            PerformActions(vb,no);    /* Recursively check each items table code */
#                            disable_sysfunc=0;
#                            if(CountCarried()==$GameHeader{MaxCarry})
#                            {
#                                if($SECOND_PERSON)
#                                    Output("You are carrying too much. ");
#                                else
#                                    Output("I've too much to carry. ");
#                                return(0);
#                            }
#                             Items[ct].Location= CARRIED;
#                             Redraw=1;
#                             OutBuf(Items[ct].Text);
#                             Output(": O.K.\n");
#                             f=1;
#                         }
#                         ct++;
#                    }
#                    if(f==0)
#                        Output("Nothing taken.");
#                    return(0);
#                }
#                if(no==-1)
#                {
#                    Output("What ? ");
#                    return(0);
#                }
#                if(CountCarried()==$GameHeader{MaxCarry})
#                {
#                    if($SECOND_PERSON)
#                        Output("You are carrying too much. ");
#                    else
#                        Output("I've too much to carry. ");
#                    return(0);
#                }
#                i=MatchUpItem(NounText,MyLoc);
#                if(i==-1)
#                {
#                    if($SECOND_PERSON)
#                        Output("It is beyond your power to do that. ");
#                    else
#                        Output("It's beyond my power to do that. ");
#                    return(0);
#                }
#                Items[i].Location= CARRIED;
#                Output("O.K. ");
#                Redraw=1;
#                return(0);
#            }
#            if(vb==18)
#            {
#                if(strcasecmp(NounText,"ALL")==0)
#                {
#                    int ct=0;
#                    int f=0;
#                    while(ct<=$GameHeader{NumItems})
#                    {
#                        if(Items[ct].Location==CARRIED && Items[ct].AutoGet && Items[ct].AutoGet[0]!='*')
#                        {
#                            no=WhichWord(Items[ct].AutoGet,Nouns);
#                            disable_sysfunc=1;
#                            PerformActions(vb,no);
#                            disable_sysfunc=0;
#                            Items[ct].Location=MyLoc;
#                            OutBuf(Items[ct].Text);
#                            Output(": O.K.\n");
#                            Redraw=1;
#                            f=1;
#                        }
#                        ct++;
#                    }
#                    if(f==0)
#                        Output("Nothing dropped.\n");
#                    return(0);
#                }
#                if(no==-1)
#                {
#                    Output("What ? ");
#                    return(0);
#                }
#                i=MatchUpItem(NounText,CARRIED);
#                if(i==-1)
#                {
#                    if($SECOND_PERSON)
#                        Output("It's beyond your power to do that.\n");
#                    else
#                        Output("It's beyond my power to do that.\n");
#                    return(0);
#                }
#                Items[i].Location=MyLoc;
#                Output("O.K. ");
#                Redraw=1;
#                return(0);
#            }
#        }
#    }
#    return(fl);
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
            say("$0 [-h] [-y] [-s] [-i] [-t] [-d] [-p] <gamename> [savedgame]."
            );
            exit;
        },
    );
$ARGV[0] //= 'adv00'; # XXX remove
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
    LoadDatabase($ARGV[0],$DEBUGGING);

#    if(argc==3)
#        LoadGame(argv[2]);

    Look();
    while(1) {
#        if(Redraw!=0)
#        {
#            Look();
#            Redraw=0;
#        }
        PerformActions(0,0);
#        if(Redraw!=0)
#        {
#            Look();
#            Redraw=0;
#        }
#        GetInput(&vb,&no);
#        switch(PerformActions(vb,no))
#        {
#            case -1:Output("I don't understand your command. ");
#                break;
#            case -2:Output("I can't do that yet. ");
#                break;
#        }
#        /* Brian Howarth games seem to use -1 for forever */
#        if($Items[LIGHT_SOURCE]{Location}/*==-1*/!=DESTROYED && $GameHeader{LightTime}!= -1)
#        {
#            $GameHeader{LightTime}--;
#            if($GameHeader{LightTime}<1)
#            {
#                BitFlags|=(1<<LIGHTOUTBIT);
#                if($Items[LIGHT_SOURCE]{Location}==CARRIED ||
#                    $Items[LIGHT_SOURCE]{Location}==MyLoc)
#                {
#                    if($SCOTTLIGHT)
#                        Output("Light has run out! ");
#                    else
#                        Output("Your light has run out. ");
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
#                        Output("Light runs out in ");
#                        OutputNumber($GameHeader{LightTime});
#                        Output(" turns. ");
#                    }
#                    else
#                    {
#                        if($GameHeader{LightTime}%5==0)
#                            Output("Your light is growing dim. ");
#                    }
#                }
#            }
#        }
    }
}
main();

sub _get_int {
    my $fh = shift;
    chomp(my $int = <$fh>);
    $int =~ s/^\s+|\s+$//g;
    unless ($int =~ /^[0-9]+$/ && $int >= 0) {
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
        print Dumper($GameHeader{NumActions},$Actions[-1]);
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
        print Dumper($Verbs[-1], $Nouns[-1]);
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
        print Dumper($Rooms[-1]);
        print <<'END';
large misty room with strange
unreadable letters over all the exits.
END
        exit;
    }

    for ( 0 .. $GameHeader{NumMessages} ) {    # XXX what happened here?
        push @Messages => ReadString($fh);
    }
    if(0) {
        print Dumper($GameHeader{NumMessages}, $Messages[-1],$.);
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

    ReadString($fh) for 0 .. $GameHeader{NumActions};   # skip comment strings

    my $version = _get_int($fh);
    printf(
        "Version %d.%02d of Adventure \n\n",
        $version / 100, $version % 100
    );
}

sub Look {
    my @ExitNames = qw(North South East West Up Down);

    my $r = $Rooms[MyLoc];

    if (   ( $BitFlags & ( 1 << DARKBIT ) )
        && $Items[LIGHT_SOURCE]{Location} != CARRIED
        && $Items[LIGHT_SOURCE]{Location} != MyLoc )
    {
        if ($SECOND_PERSON) {
            say("You can't see. It is too dark!");
        }
        else {
            say("I can't see. It is too dark!");
        }
        return;
    }

    if ( $r->{Text} eq '*' ) { # XXX ???
        print( $Rooms[ MyLoc + 1 ]->{Text} );
    }
    else {
        if ($SECOND_PERSON) {
            printf( "You are in a %s\n", $r->{Text} );
        }
        else {
            printf( "I'm in a %s\n", $r->{Text} );
        }
    }

    my $f = 0;
    print("\nObvious exits: ");
    foreach ( 0 .. 5 ) {
        if ( $r->{Exits}[$_] ) {
            if ( !$f ) {
                $f = 1;
            }
            else {
                print ", ";
            }
            print $ExitNames[$_];
        }
    }

    if ( !$f ) {
        say("none");
    }
    else {
        print "\n\n";
    }

    $f = 0;
    my $pos = 0;

    foreach my $i ( 0 .. $GameHeader{NumItems} ) {
        if ( $Items[$i]{Location} == MyLoc ) {
            if ( !$f ) {
                print $SECOND_PERSON
                  ? "You can also see: "
                  : "I can also see: ";
                $pos = 16;
                $f++;
            }
            else {
                print "\n";
            }
            print( $Items[$i]{Text} );
        }
    }
}
