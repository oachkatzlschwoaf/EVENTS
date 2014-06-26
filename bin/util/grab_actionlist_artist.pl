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

sub saveArtistInfo {

}

sub grabArtists {
    my ($d, $start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://actionlist.ru/artists';
    my $genres = {};

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        print "\nGET: ".$url.'&apage='.$i;

        my $r = $ua->get($url.'&apage='.$i);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new_from_content( $c );

        my @boxes = $t->look_down( 'class' => 'cont_box' );

        foreach my $b (@boxes) {
            # Title
            my @titles = $b->look_down('_tag' => 'h2');

            foreach my $t (@titles) {
                my $a = $t->find('a');
                my $title = $a->as_text();
            }

            # Genres
            my @info = $b->look_down('class' => 'info_info');
            my $info = $info[0];

            my @links = $info->look_down('_tag' => 'a');

            foreach my $a (@links) {
                $genres->{ $a->as_text }++;
            }
        }
    }

    foreach my $g (keys %$genres) {
        print "\n$g -> ".$genres->{$g};
        my $sql = "insert into `Genre` (`name`, `english_name`) values(?, ?)";
        my $sth = $d->prepare($sql);

        $sth->execute(
            '', 
            $g, 
        ); 
    }
}


# MAIN 
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

my $artists = grabArtists($d, 1, 43);

