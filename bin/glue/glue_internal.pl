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

    my $url = $api_url."/api/events/provider/".$p_id."/match?internal_id=".$i_id."&format=json&status=1";

    my $out = get($url);
    my $result = JSON::decode_json($out); 

    if ($result->{'done'} eq 'matched') {
        print " DONE! ".$result->{'match_id'};
    }
}

sub createInternal {
    my ($params, $p_id) = @_;

    my $api_url = $params->{'api_url'};

    my $url = $api_url."/api/events/internal/create?provider_event=".$p_id."&format=json";

    my $out = get($url);

    my $result = JSON::decode_json($out); 

    if ($result->{'done'} eq 'internal created') {
        print " DONE! ".$result->{'internal_id'};
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

    my $sql = "select `id`, `name`, `date`, `start`, `place` from `InternalEvent`";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };
    
    my $i = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        my $event = { };  
        
        $event->{'id'}       = $row[0];
        $event->{'name'}     = $row[1];
        $event->{'date'}     = $row[2];
        $event->{'start'}    = $row[3];
        $event->{'place'}    = $row[4];

        $events->{ $row[2] }{ $row[4] }{ $row[0] } = $event;
        $i++;
    }

    print "\nGOT $i INTERNAL EVENTS";

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
                }
            }
        }

        if ($matched != 0) {
            # Create a link InternalProvider
            print "\nEVENT $e_id TRY MATCH TO $matched ";
            match($params, $e_id, $matched);
        } else {
            # Mark ProviderEvent as 'not found event status'
            print "\nEVENT $e_id CREATE INTERNAL";
            
            createInternal($params, $e_id);
            $internal_events = getInternalEvents($d);

            #my $sql = "update `ProviderEvent` set status = 4 where id = '$e_id'";
            #my $sth = $d->prepare($sql);
            #$sth->execute(); 
        }
    }
}

# MAIN
print "\nGLUE PROVIDER EVENTS TO INTERNAL";
print "\n************************************";

my $params = getParameters();
$params = $params->{'parameters'}; 

my $config = getConfig();
$config = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# 1. Get all unmatched events with places
my $provider_events = getUnmatchedEvents($d);
print "\nGOT ".scalar(keys %$provider_events)." PROVIDER EVENTS";

# 2. Try to glue internal events
my $internal_events = getInternalEvents($d);

glueInternalEvents($d, $config, $provider_events, $internal_events);

