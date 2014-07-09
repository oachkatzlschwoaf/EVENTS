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
    'Янв' => 1,
    'Фев' => 2,
    'Мар' => 3,
    'Апр' => 4,
    'Май' => 5,
    'Июнь' => 6,
    'Июль' => 7,
    'Авг' => 8,
    'Сент' => 9,
    'Окт' => 10,
    'Нояб' => 11,
    'Дек' => 12
};

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
        $sql = "insert into `ProviderEvent` (`name`, `provider_id`, `date`, `start`, `duration`, `description`, `status`, `provider`, `link`, `place_text`) 
            values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        $sth = $d->prepare($sql);

        $sth->execute(
            $event->{'name'}, 
            $event->{'provider_id'}, 
            $event->{'start'}->ymd(), 
            $event->{'start'}->ymd().' '.$event->{'start'}->hms(), 
            $event->{'duration'}, 
            $event->{'description'}, 
            0, # unmatched status
            $provider,
            'http://www.kassir.ru'.$event->{'link'}, 
            $event->{'place'},
        ); 

        print "\n\tEVENT $e_id SAVE: ".$event->{'name'}." (".$event->{'start'}->ymd().")"; 
    }

}

sub getLastPage {
    my $ua = LWP::UserAgent->new();
    my $kassir_url = 'https://www.kassir.ru/kassir/search/index?categories=c1409';

    my $r = $ua->get($kassir_url);
    my $c = $r->decoded_content();

    my $t = HTML::TreeBuilder->new_from_content( $c );
    my @elements = $t->look_down(class => 'last');

    my $last_page = 0;

    for my $e (@elements) {
        my $a = $e->find('a');
        my $link = $a->attr('href');
        $link =~ /page=(\d+)/;

        $last_page = $1;
    }

    return $last_page;
}

sub grabEvents {
    my ($start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $kassir_url = 'https://www.kassir.ru/kassir/search/index?categories=c1409';
    my $events = {};

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        my $r = $ua->get($kassir_url.'&page='.$i);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new_from_content( $c );
        my @elements = $t->look_down(class => 'b-event-item__line__info');

        for my $e (@elements) {
            # Title
            my @titles = $e->look_down(class => 'b-event-item__line__info__name');
            my $event = { };

            foreach my $t (@titles) {
                my $a = $t->find('a');

                $event->{'name'} = $a->as_text();
                $event->{'link'} = $a->attr('href');

                $event->{'link'} =~ m#view/(\d+)#;
                $event->{'provider_id'} = $1;
            }


            # Date
            my @date = $e->look_down(class => 'date');
            my $dt = DateTime->now();

            foreach my $d (@date) {
                $d->as_text() =~ /(\d+) (\w+)/;

                my $e_dt = DateTime->new(
                    year  => $dt->year, # TODO! FIXIT!
                    month => $month->{$2},
                    day   => $1,
                );

                $event->{'start'} = $e_dt;
            }

            # Time
            my @time = $e->look_down(class => 'time');

            foreach my $t (@time) {
                $t->as_text() =~ /(\d+):(\d+)/;

                $event->{'start'}->set_hour($1);
                $event->{'start'}->set_minute($2);
            }

            $event->{'duration'} = 3; # TODO! FIXIT!

            # Place
            my @place = $e->look_down(class => 'b-event-item__line__info__place hoveritem');
            foreach my $p (@place) {
                my @ptext = $p->look_down(class => 'text');
                my $pname = $ptext[0]->as_text();

                $event->{'place'} = $pname;
            }

            if (!$event->{'place'}) {
                my @place = $e->look_down(class => 'b-event-item__line__info__place');
                foreach my $p (@place) {
                    $event->{'place'} = $p->as_text();
                }
            }

            $events->{ $event->{'provider_id'} } = $event;

            #print "\n* ".$event->{'name'}." ".$event->{'start'}->ymd()." ".$event->{'place'};
        }
    }

    return $events;
}

# MAIN
print "\nGRAB KASSIR";
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
saveProviderEvents($events, 1, $d); # 1 = KASSIR


