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
    my $url = 'http://ponominalu.ru/category/concerts';

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $t = HTML::TreeBuilder->new_from_content( $c );
    my @elements = $t->look_down(class => 'days');
    @elements = $elements[0]->look_down(_tag => 'a');

    my $last_page = 0;

    for my $e (@elements) {
        my $link = $e->attr('data-href');

        $link =~ /page=(\d+)/;
        $last_page = $1;
    }

    return $last_page;
}

sub grabEvents {
    my ($start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://ponominalu.ru/category/concerts';
    my $events = {};

    for (my $i = $start_page; $i <= $last_page; $i++) {  
        #print "\n\tGET ".$url.'?page='.$i;
        my $r = $ua->get($url.'?page='.$i);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new();
        $t->ignore_unknown(0);
        $t->parse( $c );
        $t->eof();
        my @elements = $t->look_down(class => 'ainfo');

        for my $e (@elements) {
            my $event = { };

            # Link, Provider Id
            my $a = $e->find('a');
            next if $a->attr('href') !~ m#^/event/(.+)#;

            $event->{'provider_id'} = $1;
            $event->{'link'} = 'http://ponominalu.ru'.$a->attr('href').'?promote=4cd1106f24cc9bc14463507b47cf6ef0';

            # Name 
            my @titles = $e->look_down(itemprop => 'name');
            $event->{'name'} = $titles[0]->as_text(); 

            # Place 
            $event->{'place'} = $titles[1]->as_text(); 

            # Date
            my $date = $e->find('time');
            my $start = $date->attr('datetime');

            my $dt = DateTime->now();

            if ($start =~ /(\d{4})\-(\d{2})\-(\d{2})T(\d{2})\:(\d{2})/) {
                my $e_dt = DateTime->new(
                    year   => $1, 
                    month  => $2,
                    day    => $3,
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
print "\nGRAB PONOMINALU";
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

saveProviderEvents($events, 3, $d); # 3 = PONOMINALU 


