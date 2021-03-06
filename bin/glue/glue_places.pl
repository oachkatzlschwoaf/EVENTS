#!/usr/bin/perl

use strict;
use warnings;

$|++;

use utf8;

use DateTime;
use Encode;
use Data::Dumper;
use LWP::Simple;
use HTML::TreeBuilder;
use JSON;
use YAML;
use DBI;
use Text::Levenshtein::XS qw/distance/;

binmode STDOUT, ':utf8';

sub trim($) {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

sub getParameters{
    return YAML::LoadFile("../app/config/parameters.yml");
}

sub connectDb {
    my ($c) = @_;

    return DBI->connect(
        'dbi:mysql:'.$c->{'database_name'}.':'.$c->{'database_host'}.':'.$c->{'database_port'}, 
        $c->{'database_user'}, 
        $c->{'database_password'}
    );
}

sub getUnmatchedEvents {
    my ($d) = @_;

    # Get unmatched events or events w/o place
    my $sql = "select `id`, `name`, `date`, `start`, `place_text` from `ProviderEvent` where place = 0 and (status = '0' or status = '3')";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };

    while ( my @row = $sth->fetchrow_array() ) {
        my $event = { };  
        
        $event->{'id'} = $row[0];
        $event->{'name'} = $row[1];
        $event->{'date'} = $row[2];
        $event->{'start'} = $row[3];
        $event->{'place_text'} = $row[4];

        $events->{ $row[0] } = $event;
    }

    return $events;
}

sub getPlaces {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `keywords`, `status` from `Place`";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $places = { };
    
    while ( my @row = $sth->fetchrow_array() ) {
        my $place = { };  
        
        $place->{'id'}       = $row[0];
        $place->{'name'}     = $row[1];
        $place->{'keywords'} = $row[2];
        $place->{'status'}   = $row[3];

        $places->{ $row[0] } = $place;
    }

    return $places;
}

sub getInternalEvents {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `date`, `start`, `place` from `InternalEvent` where status = 1";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };
    
    while ( my @row = $sth->fetchrow_array() ) {
        my $event = { };  
        
        $event->{'id'}       = $row[0];
        $event->{'name'}     = $row[1];
        $event->{'date'}     = $row[2];
        $event->{'start'}    = $row[3];
        $event->{'place'}    = $row[4];

        $events->{ $row[2] }{ $row[4] }{ $row[0] } = $event;
    }

    return $events;
}

sub gluePlaces {
    my ($d, $events, $places) = @_;
    
    foreach my $e_id (keys %$events) {
        my $e = $events->{$e_id};

        my $e_place = $e->{'place_text'};
        Encode::_utf8_on($e_place);
        $e_place = lc($e_place);
        $e_place =~ s/[\"\'\(\)]//g;

        print "\n\tEVENT $e_id ('$e_place') ";

        my $best_result = 100;
        my $res_place   = 0;
        my $kw_matched  = '';

        foreach my $p_id (keys %$places) {
            my $p = $places->{$p_id};

            # Extract keywords
            my @keywords; 
            if ($p->{'keywords'}) {
                @keywords = map { trim($_); } split(/,/, $p->{'keywords'});
            }

            push(@keywords, $p->{'name'});

            foreach my $kw (@keywords) {
                Encode::_utf8_on($kw);
                $kw = lc($kw);
                $kw =~ s/[\"\'\(\)]//g;

                my $dist = distance($e_place, $kw);
                my $dist_p = abs( int( $dist * 100 / length($e_place) ) );

                if ($dist_p < 10 && $dist_p < $best_result) {
                    if ($dist_p < $best_result) {
                        $best_result = $dist_p;
                        $res_place   = $p_id;
                        $kw_matched  = $kw;
                    }
                }
            }
        }

        if ($best_result < 100 && $res_place != 0) {
            print "MATCH TO '$kw_matched'";

            # Save Place in Provider Event
            $e->{'place'} = $res_place;
            my $sql = "update `ProviderEvent` set place = '$res_place' where id = '$e_id'";
            my $sth = $d->prepare($sql);
            $sth->execute(); 

            if ($places->{$res_place}{'status'} == 0) {
                print " AND CANCEL";
                my $sql = "update `ProviderEvent` set status = '2' where id = '$e_id'";
                my $sth = $d->prepare($sql);
                $sth->execute(); 
            }

        } else {
            # Mark ProviderEvent as 'without place' and delete from hash
            print " NOT FOUND PLACE";

            my $sql = "update `ProviderEvent` set status = '3' where id = '$e_id'";
            my $sth = $d->prepare($sql);
            $sth->execute(); 

            delete( $events->{$e_id} );
        }
    }

    return $events;
}

# MAIN
print "\nGLUE PROVIDER EVENTS TO PLACES";
print "\n************************************";

my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# 1. Get all unmatched events
my $events = getUnmatchedEvents($d);
print "\nGOT ".scalar(keys %$events)." EVENTS TO GLUE"; 

# 2. Try to glue places
my $places = getPlaces($d);
print "\nGOT ".scalar(keys %$places)." PLACES";

gluePlaces($d, $events, $places);
