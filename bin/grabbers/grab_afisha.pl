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

        print "\n\tSAVE $e_id. ".$event->{'name'}." (".$event->{'start'}->ymd().")"; 
    }
}


sub grabEvents {
    my $ua = LWP::UserAgent->new();
    my $events = {};

    my $dt = DateTime->today()
        ->truncate( to => 'week' );

    my $ndt = DateTime->now();

    foreach (my $i = 0; $i < 24; $i++) {
        my $monday = $dt->strftime('%d-%m-%Y');

        my $url = "http://www.afisha.ru/msk/schedule_concert/sortbydate/$monday/reset/";

        print "\n\tGET ".$url;
        my $r = $ua->get($url);
        my $c = $r->decoded_content();

        my $t = HTML::TreeBuilder->new();
        $t->ignore_unknown(0);
        $t->parse( $c );
        $t->eof();

        my @elements = $t->look_down(class => 's-votes-hover-area');

        foreach my $e (@elements) {
            my $event = { };

            my @hs = $e->look_down(_tag => 'h3');
            my $a = $hs[0]->find('a');

            # Name, Link, Provider Id
            $event->{'name'} = trim($a->as_text()); 
            $event->{'link'} = $a->attr('href');

            $a->attr('href') =~ m#concert/(\d+)#;

            $event->{'provider_id'} = $1;

            # Place
            my @ps = $e->look_down(class => 'object-type');
            $a = $ps[0]->find('a');

            $event->{'place'} = trim($a->as_text()); 

            # Date
            my @ds = $e->look_down(class => 'b-td-date');
            my $dtxt = $ds[0]->as_text();

            $dtxt =~ /(\d+) (\w+), (\d+)\:(\d+)/;

            my $d = $1;
            my $m = $month->{$2};
            my $h = $3;
            my $mi = $4;
            my $y = $ndt->year();

            $y++ if ($m < $ndt->month());

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

        $dt->add(days => 7);
    }


    return $events;
}

# MAIN
print "\n\n\nGRAB AFISHA EVENTS";
print "\n**********";

# PARAM
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

print "\nGRAB EVENTS...";
my $events = grabEvents();

print "\n".scalar(keys %$events)." EVENTS FOUND";

print "\nSAVE EVENTS...";
saveProviderEvents($events, 8, $d); # 8 = AFISHA 


