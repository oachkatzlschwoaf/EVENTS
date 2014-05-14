#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use DateTime;
use Encode;
use Data::Dumper;
use LWP::Simple;
use HTML::TreeBuilder;
use JSON;
use YAML;
use DBI;

$|++;
binmode STDOUT, ':utf8';
my $API_URL = "http://localhost/events/app_dev.php";

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

sub cancelInternalEvents {
    my ($d, $place_id) = @_;

    my $sql = "update `InternalEvent` set status = '2' where place = '$place_id'";
    my $sth = $d->prepare($sql);
    $sth->execute(); 
}

sub cancelProviderEvents {
    my ($d, $place_id) = @_;

    my $sql = "update `ProviderEvent` set status = '2' where place = '$place_id'";
    my $sth = $d->prepare($sql);
    $sth->execute(); 
}

# MAIN
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

my $places = getPlaces($d);

foreach my $p_id (keys %$places) {
    my $p = $places->{$p_id};

    if ($p->{'status'} == 0) {
        # Switch off internal events

        # Switch off provider events
        print "\n$p_id > cancel events";
        cancelInternalEvents($d, $p_id);
        cancelProviderEvents($d, $p_id);
    }
}



