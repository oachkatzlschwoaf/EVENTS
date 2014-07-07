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

        print "\n\tSAVE $e_id. ".$event->{'name'}." (".$event->{'start'}->ymd().")"; 
    }

}

sub getLastPage {
    my $ua = LWP::UserAgent->new();
    my $url = 'http://www.ticketland.ru/concert/';

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $t = HTML::TreeBuilder->new_from_content( $c );
    my @elements = $t->look_down(class => 'pagecount');

    my $last_page = $elements[0]->as_text();
    $last_page =~ /(\d+)/;

    $last_page = $1;

    return $last_page;
}

sub grabEvents {
    my ($start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://www.ticketland.ru/concert/';
    my $events = {};

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        print "\n\tGET ".$url.$i.'/';
        my $r = $ua->get($url.$i.'/');
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new();
        $t->ignore_unknown(0);
        $t->parse( $c );
        $t->eof();

        my @elements = $t->look_down(class => 'show_block');

        for my $e (@elements) {
            my $event = { };
    
            my @as = $e->look_down(class => 'showname');
            my $a = $as[0]->find('a');

            # Link, Provider Id
            $event->{'provider_id'} = $a->attr('href');
            $event->{'link'} = 'http://www.ticketland.ru'.$a->attr('href');

            # Name 
            $event->{'name'} = $a->as_text(); 

            # Place 
            my @pl = $e->look_down(class => 'build_name');
            $event->{'place'} = $pl[0]->as_text(); 

            # Date
            my @ds = $e->look_down(class => 'startdate');
            my $da = $ds[0]->find('a');

            $da->attr('href') =~ /(\d+)_(\d+)-(\d+)/;

            my $y = substr($1, 0, 4); 
            my $m = substr($1, 4, 2); 
            my $d = substr($1, 6, 2); 

            my $h = substr($2, 0, 2); 
            my $mi = substr($2, 2, 2); 

            my $e_dt = DateTime->new(
                year   => $y, 
                month  => $m,
                day    => $d,
                hour   => $h,
                minute => $mi,
            );

            $event->{'start'} = $e_dt;

            # Duration (TODO: Fixit)
            $event->{'duration'} = 3;

            $events->{ $event->{'provider_id'} } = $event;
        }
    }

    return $events;
}

# MAIN
print "\n\n\nGRAB TICKETLAND EVENTS";
print "\n**********";

# PARAM
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# Get Last Page
my $last = getLastPage();

print "\nGRAB EVENTS...";
my $events = grabEvents(1, $last);

print "\n".scalar(keys %$events)." EVENTS FOUND";

print "\nSAVE EVENTS...";
saveProviderEvents($events, 5, $d); # 5 = TICKETLAND 


