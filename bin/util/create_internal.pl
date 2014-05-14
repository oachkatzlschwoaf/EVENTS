#!/usr/bin/perl

use utf8;
use strict;
use warnings;

$|++;

use DateTime;
use Encode;
use Data::Dumper;
use LWP::Simple;
use HTML::TreeBuilder;
use JSON;
use YAML;
use DBI;

sub getParameters{
    return YAML::LoadFile("../../app/config/parameters.yml");
}

sub connectDb {
    my ($c) = @_;

    return DBI->connect(
        'dbi:mysql:'.$c->{'database_name'}.':'.$c->{'database_host'}.':'.$c->{'database_port'}, 
        $c->{'database_user'}, 
        $c->{'database_password'}
    );
}

sub getProviderEvents {
    my ($d) = @_;

    my $sql = "select `id` from `ProviderEvent` where status = '4'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };

    while ( my @row = $sth->fetchrow_array() ) {
        my $event = { };  
        
        $event->{'id'} = $row[0];

        $events->{ $event->{'id'} } = $event;
    }

    return $events;
}


# MAIN 
my $API_URL = "http://localhost/events/app_dev.php";

my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

my $events = getProviderEvents($d);

foreach my $p_id (keys %$events) {
    print "\n>$p_id";
    my $url = $API_URL."/admin/events/internal/create?provider_event=".$p_id."&format=json";
    my $result = get($url); 
    
    print "\n$result";
}

