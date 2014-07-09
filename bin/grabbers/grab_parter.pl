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

        print "\n\tEVENT $e_id SAVE: ".$event->{'name'}." (".$event->{'start'}->ymd().")"; 
    }

}

sub getLastPage {
    my $ua = LWP::UserAgent->new();
    my $url = 'http://www.parter.ru/bilety-%D0%BC%D0%BE%D1%81%D0%BA%D0%B2%D0%B0.html?doc=city&fun=ortsliste&hkId=74&ortId=288';

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $t = HTML::TreeBuilder->new_from_content( $c );
    my @elements = $t->look_down(class => 'headlinePager');
    @elements = $elements[0]->look_down(_tag => 'a');

    my $last_page = 0;

    for my $e (@elements) {
        my $num = $e->as_text;

        if ($num =~ /(\d+)/) {
            $last_page = $1;
        }
    }

    return $last_page;
}

sub grabEvents {
    my ($start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://www.parter.ru/bilety-%D0%BC%D0%BE%D1%81%D0%BA%D0%B2%D0%B0.html?doc=city&fun=ortsliste&hkId=74&ortId=288';
    my $events = {};

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        my $num = ($i - 1) * 25;

        #print "\n\tGET ".$url.'&index_event='.$num;
        my $r = $ua->get($url.'&index_event='.$num);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new();
        $t->ignore_unknown(0);
        $t->parse( $c );
        $t->eof();

        my @elements = $t->look_down(class => 'line');

        for my $e (@elements) {
            my $event = { };

            # Link, Provider Id
            my $a = $e->find('a');
            next if $a->attr('href') !~ m#^(bilety-.*)\.html#;

            $event->{'provider_id'} = $1;
            $event->{'link'} = 'http://www.parter.ru/'.$a->attr('href');

            # Name 
            $event->{'name'} = $a->as_text(); 

            # Place 
            my $pl = $e->find('dt');
            $event->{'place'} = $pl->as_text(); 

            # Date
            my $abbr = $e->find('abbr');

            my $start = $abbr->as_text();

            my $dt = DateTime->now();

            if ($start =~ /(\d{2})\.(\d{2})\.(\d{2}) \/ (\d{2})\:(\d{2})/) {
                my $e_dt = DateTime->new(
                    year   => "20".$3, 
                    month  => $2,
                    day    => $1,
                    hour   => $4,
                    minute => $5,
                );

                $event->{'start'} = $e_dt;
            } else {
                next;
            }

            # Duration (TODO: Fixit)
            $event->{'duration'} = 3;

            $events->{ $event->{'provider_id'} } = $event;
        }
    }

    return $events;
}

# MAIN
print "\nGRAB PARTER";
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

saveProviderEvents($events, 4, $d); # 4 = PARTER 


