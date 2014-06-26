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
use Text::Levenshtein::XS qw/distance/;

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

sub clean {
    my ($k) = @_;
    Encode::_utf8_on($k);

    $k = lc($k);
    $k =~ s/[\"\'\(\)]//g;
    $k =~ s/^\s+//;
    $k =~ s/\s+$//;
    return $k;
}

sub grabPlaces{
    my ($d, $start_page, $last_page, $places) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://actionlist.ru/clubs';
    my $genres = {};

    my $ret;

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        print "\nGET: ".$url.'&cpage='.$i;

        my $r = $ua->get($url.'&cpage='.$i);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new_from_content( $c );

        my @urls = $t->look_down( 'itemprop' => 'contentUrl' );

        foreach my $u (@urls) {
            #print "\n\n\t".$u->attr('href');
            my $ur = $ua->get($u->attr('href'));
            my $uc = $ur->decoded_content();
            my $ut = HTML::TreeBuilder->new_from_content( $uc );

            $uc =~ m#<strong class="buttonh" id="top_a"><span itemprop="name">(.*?)</span></strong><br>#;
            my $name = $1;

            $uc =~ m#<span itemprop="streetAddress">(.*?)</span>#;
            my $address = $1;

            my $metro = '';
            if ($uc =~ m#"icon_metro">&nbsp;</span>(.*?)<hr></span>#) {
                $metro = $1;
            }

            my $phone = '';
            if ($uc =~ m#"callto://(.*?)"#) {
                $phone = $1;
            }

            my $club_url = '';
            if ($uc =~ m#<a href="(.*?)" target="_blank" rel='nofollow' itemprop='url'>#) {
                $club_url = $1;
            }

            my $long = '';
            my $lat  = '';
            my $zoom = '';
            if ($uc =~ m#new YMaps.GeoPoint\((.*?), (.*?)\), (\d+)#) {
                $long = $1;
                $lat  = $2;
                $zoom = $3;
            }

            $ret->{ $name } = {
                'name'    => $name,
                'address' => $address,
                'metro'   => $metro,
                'phone'   => $phone,
                'url'     => $club_url,
                'lat'     => $lat,
                'long'    => $long,
                'zoom'    => $zoom
            };
        
        }
    }

    return $ret;
}

sub getCurrentPlaces {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `keywords` from `Place` where status = 1";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $places = { };
    
    while ( my ($id, $name, $keywords) = $sth->fetchrow_array() ) {
        
        $places->{$id} = [ clean($name) ];

        if ($keywords) {
            foreach my $k (split(',', $keywords)) {
                push( @{ $places->{$id} }, clean($k) );
            }
        }
    }

    return $places;
}


# MAIN 
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");
$d->{'mysql_enable_utf8'} = 1;

my $places = getCurrentPlaces($d);

my $clubs = grabPlaces($d, 1, 12, $places);

foreach my $pid (keys $places) {
    my $name = $places->{$pid}[0];

    my $match = { };
    my $min_dist = 100;

    foreach my $kw (@{ $places->{$pid} }) {
        foreach my $c (keys %$clubs) {
            my $dist = distance($kw, clean($c));

            if ($dist < $min_dist) {
                $min_dist = $dist;
                $match = $clubs->{$c};
            }
        }
    }

    if ($min_dist == 0) {
        print "\n$pid. '$name','".$match->{'name'}."',$min_dist";

        my $sql = "update `Place` set 
        address = '".$match->{'address'}."', 
        phone = '".$match->{'phone'}."', 
        url = '".$match->{'url'}."', 
        latitude = '".$match->{'lat'}."', 
        longitude = '".$match->{'long'}."', 
        zoom = '".$match->{'zoom'}."' 
        where id = '$pid'";
        my $sth = $d->prepare($sql);
        $sth->execute(); 
    }
}

