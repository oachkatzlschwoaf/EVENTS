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
    my ($d, $events, $provider) = @_;

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
            'http://www.concert.ru/'.$event->{'link'}, 
            $event->{'place'},
        ); 

        print "\n\tEVENT $e_id SAVE: ".$event->{'name'}." (".$event->{'start'}->ymd().")"; 
    }

}

sub getLastPage {
    my $ua = LWP::UserAgent->new();
    my $url = 'http://www.concert.ru/Actions.aspx?ActionTypeID=1';

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $t = HTML::TreeBuilder->new_from_content( $c );

    my @elements = $t->look_down(class => 'PagerHyperlinkStyle');

    my $last_page = 0;

    for my $e (@elements) {
        my $link = $e->attr('href');

        next if (!$link);
        $link =~ /,'(\d+)'\)/;

        $last_page = $1 if ($1 > $last_page);
    }

    return $last_page;
}

sub grabEvents {
    my ($start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://www.concert.ru/Actions.aspx?ActionTypeID=1&__EVENTTARGET=ctl00$MainPage$pager1';
    my $events = {};

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        my $r = $ua->get($url.'&__EVENTARGUMENT='.$i);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new_from_content( $c );

        my @elements = $t->look_down(class => 'actionData');

        for my $e (@elements) {
            my $event = { };

            # Name, Link, Provider Id
            my @titles = $e->look_down(class => 'actionTitle');

            foreach my $t (@titles) {
                my $div = $t->find('div');

                $event->{'name'} = $div->as_text();

                $event->{'link'} = $t->attr('href');
                $event->{'link'} =~ m#ActionID=(\d+)#;
                $event->{'provider_id'} = $1;
            }

            # Date
            my $date = $e->as_text();
            my $dt = DateTime->now();

            if ($date =~ /(\d{2})\.(\d{2})\.(\d{4}) (\d{2})\:(\d{2})/) {
                my $e_dt = DateTime->new(
                    year   => $3, 
                    month  => $2,
                    day    => $1,
                    hour   => $4,
                    minute => $5,
                );

                $event->{'start'} = $e_dt;
            } else {
                next;
            }

            # Duration
            $event->{'duration'} = 3; # TODO! FIXIT!

            # Place
            my @place = $e->look_down(class => 'ActionExtraData');
            foreach my $p (@place) {
                my $span = $p->find('span');
                if ($span) {
                    my $pname = $span->as_text();
                    $event->{'place'} = $pname;
                } else {
                    next;
                }
            }

            next if (!$event->{'place'});

            $events->{ $event->{'provider_id'} } = $event;

            #print "\n* $i. ".$event->{'name'}." ".$event->{'start'}->ymd()." ".$event->{'place'};
        }
    }

    return $events;
}

# MAIN
print "\nGRAB CONCERT";
print "\n************************************";

# PARAM
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

my $last = getLastPage();
my $events = grabEvents(1, $last);

print "\nGOT ".scalar(keys %$events)." EVENTS";
saveProviderEvents($d, $events, 2); # 2 = CONCERT 


