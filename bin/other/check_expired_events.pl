#!/usr/bin/perl

use strict;
use warnings;

use DateTime;
use Encode;
use Data::Dumper;
use LWP::Simple;
use LWP::UserAgent;
use HTML::TreeBuilder;
use JSON;
use YAML;
use DBI;

$|++;

binmode STDOUT, ':utf8';

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

sub isActive {
    my ($d, $e) = @_;

    my $ua = LWP::UserAgent->new(); 
    my $response = $ua->get( $e->{'link'} );

    if ($response->code ne '200') {
        print "\ncheck ".$e->{'id'}." (".$e->{'link'}.")";
        print " -> ERROR: code ".$response->code;
    }

    if ($e->{'provider'} != 1 && $response->is_success and $response->previous ) {
        print "\ncheck ".$e->{'id'}." (".$e->{'link'}.")";
        print " -> ERROR: redirect ";
    }
}

sub getProviderEvents {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `date`, `start`, `place_text`, `place`, `provider`, `provider_id`, `link` from `ProviderEvent` where status != 5";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };

    while ( my @row = $sth->fetchrow_array() ) {
        my $event = { };  
        
        $event->{'id'} = $row[0];
        $event->{'date'} = $row[2];
        $event->{'provider'} = $row[6];
        $event->{'link'} = $row[8];

        $events->{ $event->{'id'} } = $event;
    }

    return $events;
}

sub getInternalEvents {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `date` from `InternalEvent` where status != 3";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };

    while ( my @row = $sth->fetchrow_array() ) {
        my $event = { };  
        
        $event->{'id'} = $row[0];
        $event->{'date'} = $row[2];

        $events->{ $event->{'id'} } = $event;
    }

    return $events;
}

sub outdateProviderEvent {
    my ($d, $id) = @_;

    my $sql = "update `ProviderEvent` set status = '5' where id = '$id'";
    my $sth = $d->prepare($sql);
    $sth->execute(); 
}

sub outdateInternalEvent {
    my ($d, $id) = @_;

    my $sql = "update `InternalEvent` set status = '3' where id = '$id'";
    my $sth = $d->prepare($sql);
    $sth->execute(); 
}

# MAIN
print "\nCHECK EXPIRED EVENTS";
print "\n************************************";

my $config = getParameters();
my $params = $config->{'parameters'}; 

my $dt_now = DateTime->now();
$dt_now->subtract( days => 1 );

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# Provider Events Outdate
my $provider_events = getProviderEvents($d);
print "\nGOT ".scalar(keys %$provider_events)." PROVIDER EVENTS TO CHECK";

foreach my $e_id (keys %$provider_events) {
    my $e = $provider_events->{$e_id};

    $e->{'date'} =~ /(\d{4})-(\d{2})-(\d{2})/;
    my $dt = DateTime->new(
        year  => $1,
        month => $2,
        day   => $3
    );

    if ($dt_now > $dt) {
        print "\nPROVIDER EVENT $e_id EXPIRED (".$dt->ymd().")";
        outdateProviderEvent($d, $e_id)
    }
}

my $internal_events = getInternalEvents($d);
print "\n\nGOT ".scalar(keys %$provider_events)." INTERNAL EVENTS TO CHECK";

foreach my $e_id (keys %$internal_events) {
    my $e = $internal_events->{$e_id};
    $e->{'date'} =~ /(\d{4})-(\d{2})-(\d{2})/;
    
    my $dt = DateTime->new(
        year  => $1,
        month => $2,
        day   => $3
    );

    if ($dt_now > $dt) {
        print "\nINTERNAL EVENT $e_id EXPIRED (".$dt->ymd().")";
        outdateInternalEvent($d, $e_id)
    }
}
