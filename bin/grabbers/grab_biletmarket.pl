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

my $month = {
    'января' => 1,
    'февраля' => 2,
    'марта' => 3,
    'апреля' => 4,
    'мая' => 5,
    'июня' => 6,
    'июля' => 7,
    'августа' => 8,
    'сентября' => 9,
    'октября' => 10,
    'ноября' => 11,
    'декабря' => 12
};

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

sub saveProviderEvents {
    my ($events, $provider, $d) = @_;

    foreach my $e_id (keys %$events) {
        my $event = $events->{$e_id};

        # Check is exist or not
        my $sql = "select * from `ProviderEvent` where provider_id = '$e_id'";
        my $sth = $d->prepare($sql);
        $sth->execute();

        if ( my @row = $sth->fetchrow_array() ) {
            next;
        }
        
        # Save
        $sql = "insert into `ProviderEvent` (`name`, `provider_id`, `date`, `start`, `duration`, `status`, `provider`, `link`, `place_text`) 
            values(?, ?, ?, ?, ?, ?, ?, ?, ?)";
        $sth = $d->prepare($sql);

        $sth->execute(
            $event->{'name'}, 
            $event->{'provider_id'}, 
            $event->{'start'}->ymd(), 
            $event->{'start'}->ymd().' '.$event->{'start'}->hms(), 
            $event->{'duration'}, 
            0, # unmatched status
            $provider,
            $event->{'link'},
            $event->{'place'},
        ); 

        print "\n\tEVENTS $e_id SAVE: ".$event->{'name'}." (".$event->{'start'}->ymd().")"; 
    }

}

sub getLastPage {
    my $ua = LWP::UserAgent->new();
    my $url = 'http://biletmarket.ru/eventslist.html?rubric=126';

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $t = HTML::TreeBuilder->new_from_content( $c );
    my @elements = $t->look_down(class => 'paging');
    @elements = $elements[0]->look_down(_tag => 'a');

    my $last_page = 0;

    for my $e (@elements) {
        my $link = $e->as_text();
        $last_page = $link;
    }

    return $last_page;
}

sub grabEvents {
    my ($start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://biletmarket.ru/eventslist.html?rubric=126';
    my $events = {};

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        my $num = ($i - 1) * 12;

        #print "\n\tGET ".$url.'&page='.$num;
        my $r = $ua->get($url.'&page='.$num);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new();
        $t->ignore_unknown(0);
        $t->parse( $c );
        $t->eof();

        my @elements = $t->look_down(class => 'day');

        my $dt = DateTime->now();

        for my $e (@elements) {

            my @dts = $e->look_down(class => 'date');
            my $ds = $dts[0]->as_text();

            $ds =~ /(\d+) (\w+)/;
            my $d = $1;
            my $m = $month->{$2};
            my $y = $dt->year();
            $y++ if ($m < $dt->month());

            my @evs = $e->look_down(_tag => 'tr');

            foreach my $v (@evs) {
                my $event = { };

                my @ts = $v->look_down(class => 'text');
                my $title = $ts[0]->as_text();

                $title =~ m#(.*)/(.*)#;

                # Name 
                $event->{'name'} = trim($1); 

                # Place 
                $event->{'place'} = trim($2); 

                # Link, Provider Id
                my @ls = $v->look_down(class => 'order');
                my $a = $ls[0]->find('a');

                $event->{'link'} = 'http://biletmarket.ru'.$a->attr('href');

                $a->attr('href') =~ m#events/(\d+)/#; 

                $event->{'provider_id'} = $1;
                
                # Date 
                my @tm = $v->look_down(class => 'time');
                $tm[0]->as_text() =~ /(\d+)\:(\d+)/;

                my $e_dt = DateTime->new(
                    year   => $y, 
                    month  => $m,
                    day    => $d,
                    hour   => $1,
                    minute => $2,
                );

                $event->{'start'} = $e_dt;

                # Duration (TODO: Fixit)
                $event->{'duration'} = 3;

                $events->{ $event->{'provider_id'} } = $event;
            }
        }
    }

    return $events;
}

# MAIN
print "\nGRAB BILETMARKET";
print "\n************************************";

# PARAM
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# Get Last Page
my $last = getLastPage();

my $events = grabEvents(1, $last);

print "\nGOT ".scalar(keys %$events)." EVENTS";

saveProviderEvents($events, 7, $d); # 7 = BILETMARKET 


