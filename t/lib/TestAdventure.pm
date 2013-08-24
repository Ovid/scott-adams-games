package TestAdventure;

use strict;
use warnings;
use Carp;

# load the driver at BEGIN time
use FindBin;

BEGIN {

    package Tests::SAG;
    require "$FindBin::Bin/../bin/scott.pl";
}

use Capture::Tiny 'capture_stdout';
use Test::More;

sub import {
    my ( $class, $game ) = @_;
    Tests::SAG::LoadDatabase($game);

    my $caller = caller;

    no strict 'refs';
    *{"${caller}::look"}       = \&look;
    *{"${caller}::is_similar"} = \&is_similar;
    *{"${caller}::doit"}       = \&doit;
}

sub look { Tests::SAG::Look() }

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
    my ($command) = @_;

    my ( $verb, $noun ) = map {lc} split /\s+/ => $command;

    my $verb_id = Tests::SAG::WhichWord( $verb, \@Tests::SAG::Verbs ) or return "Unknown verb '$verb'";

    my $noun_id;
    if ( defined $noun && 'all' ne $noun ) {
        $noun_id = Tests::SAG::WhichWord( $noun, \@Tests::SAG::Nouns ) or return "Unknown noun '$noun'";
    }
    {
        no warnings 'once';
        $Tests::SAG::NounText = $noun // '';
    }
    return capture_stdout {
        Tests::SAG::PerformActions( $verb_id, $noun_id );
    };
}

1;
