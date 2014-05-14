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

sub match {
    my ($params, $p_id, $i_id) = @_;

    my $api_url = $params->{'api_url'};

    my $url = $api_url."/api/events/provider/".$p_id."/match?internal_id=".$i_id."&format=json&status=0";

    my $out = get($url);
    my $result = JSON::decode_json($out); 

    if ($result->{'done'} eq 'matched') {
        print " -> matched! ".$result->{'match_id'};
    }
}

sub getConfig {
    return YAML::LoadFile("../app/config/config.yml");
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
    my $sql = "select `id`, `name`, `date`, `start`, `place_text`, `place` from `ProviderEvent` where place != 0 and (status = '0' or status = '4' or status = '3')";
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
        $event->{'place'} = $row[5];

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

        print "\n$e_id. '$e_place' glue place...";

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
                    #print "\n\t$e_place  => $kw = ".$dist." ".$dist_p."% ($best_result)";
                    if ($dist_p < $best_result) {
                        $best_result = $dist_p;
                        $res_place   = $p_id;
                        $kw_matched  = $kw;
                    }
                }
            }
        }

        if ($best_result < 100 && $res_place != 0) {
            print "\n\tmatch to '$kw_matched' ($res_place) $best_result%";

            # Save Place in Provider Event
            $e->{'place'} = $res_place;
            my $sql = "update `ProviderEvent` set place = '$res_place' where id = '$e_id'";
            my $sth = $d->prepare($sql);
            $sth->execute(); 

        } else {
            # Mark ProviderEvent as 'without place' and delete from hash
            print " not found place";

            my $sql = "update `ProviderEvent` set status = '3' where id = '$e_id'";
            my $sth = $d->prepare($sql);
            $sth->execute(); 

            delete( $events->{$e_id} );
        }
    }

    return $events;
}

sub glueInternalEvents {
    my ($d, $params, $events, $internal_events) = @_;

    foreach my $e_id (keys %$events) {
        my $e = $events->{$e_id};

        next if ($e->{'place'} == 0);

        my $ievents = $internal_events->{ $e->{'date'} }{ $e->{'place'} };
        my $matched = 0;

        if ($ievents && scalar(keys %$ievents) > 0) {
            foreach my $ie_id (keys $ievents) {
                my $ie = $ievents->{$ie_id};

                if ($ie->{'start'} eq $e->{'start'}) {
                    # We found a leader!
                    $matched = $ie->{'id'};
                    last;
                } else {
                    # TODO: Check names
                }
            }
        }

        if ($matched != 0) {
            # Create a link InternalProvider
            print "\n$e_id > $matched ";
            match($params, $e_id, $matched);
        } else {
            # Mark ProviderEvent as 'not found event status'
            print "\n$e_id > not found internal event";
            my $sql = "update `ProviderEvent` set status = 4 where id = '$e_id'";
            my $sth = $d->prepare($sql);
            $sth->execute(); 
        }
    }
}

# MAIN
print "\n\n\nGLUE INTERNAL";
print "\n**********";

my $params = getParameters();
my $params = $params->{'parameters'}; 

my $config = getConfig();
$config = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# 1. Get all unmatched events with places
my $provider_events = getUnmatchedEvents($d);
print "\nGet ".scalar(keys %$provider_events)." provider events to glue...";

# 2. Try to glue internal events
my $internal_events = getInternalEvents($d);
print "\nGet ".scalar(keys %$internal_events)." intenrnal events to glue...";

glueInternalEvents($d, $config, $provider_events, $internal_events);

