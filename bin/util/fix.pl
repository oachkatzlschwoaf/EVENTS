#!/usr/bin/perl

use utf8;
use strict;
use warnings;

$|++;

use DateTime;
use Encode;
use Data::Dumper;
use LWP::UserAgent;
use HTML::TreeBuilder;
use JSON;
use YAML;
use DBI;

binmode STDOUT, ':utf8';

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

# MAIN 
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

my $sql = "select id, link from `ProviderEvent` where provider = '2'"; # FIX CONCERT
my $sth = $d->prepare($sql);
$sth->execute();

while ( my ($id, $link) = $sth->fetchrow_array() ) {
    print "\n$id - $link";
    $link =~ s/concert\.ru/concert.ru\//;
    print " -> $link";

    #$sql = "update `ProviderEvent` set `link` = '$link' where id = '$id'";
    #my $uth = $d->prepare($sql);
    #$uth->execute(); 
}
