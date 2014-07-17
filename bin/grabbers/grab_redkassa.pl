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

    my $save_stat = { };
    my $dt = DateTime->now();

    foreach my $e_id (keys %$events) {
        my $event = $events->{$e_id};

        # Check is exist or not
        my $sql = "select * from `ProviderEvent` where provider_id = '$e_id'";
        my $sth = $d->prepare($sql);
        $sth->execute();

        if ( my @row = $sth->fetchrow_array() ) {
            $save_stat->{'exists'}++;
            next;
        }
        
        # Save
        $sql = "insert into `ProviderEvent` (`name`, `provider_id`, `date`, `start`, `duration`, `status`, `provider`, `link`, `place_text`, `created_at`) values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
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
            $dt->ymd().' '.$dt->hms(),
        ); 

        $save_stat->{'new'}++;

        print "\n\tEVENT $e_id SAVE: ".$event->{'name'}." (".$event->{'start'}->ymd().")"; 
    }

    # Save Report as Admin Action
    $save_stat->{'provider'} = $provider;

    my $sql = "insert into `AdminAction` (`type`, `info`, `created_at`) 
        values(?, ?, ?)";
    my $sth = $d->prepare($sql);
    $sth->execute(
        4, # ACTION: GRAB
        JSON::encode_json($save_stat),
        $dt->ymd().' '.$dt->hms()
    );
}

sub grabEvents {
    my ($start_page, $last_page) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = 'http://www.redkassa.ru/events/';
    my $events = {};

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $t = HTML::TreeBuilder->new();
    $t->ignore_unknown(0);
    $t->parse( $c );
    $t->eof();

    my @elements = $t->look_down(class => 'description');

    for my $e (@elements) {
        my $event = { };

        # Link, Provider Id
        my @ts = $e->look_down(class => 'name');
        my $a = $ts[0]->find('a');

        $a->attr('href') =~ m#/events/(.*)/#;

        $event->{'provider_id'} = $1;
        $event->{'link'} = 'http://www.redkassa.ru'.$a->attr('href');

        # Name 
        $event->{'name'} = trim($a->as_text()); 

        # Place 
        my @pl = $e->look_down(class => 'place');
        $event->{'place'} = trim($pl[0]->as_text()); 

        # Date
        my @ds = $e->look_down(class => 'date');
        my $start = trim($ds[0]->as_text());

        next if ($start =~ /(\d{2})\.(\d{2})\.(\d{2}) - (\d{2})\.(\d{2})\.(\d{2})/);
        next if ($start =~ /с (\d{2}) (\w+) (\d{4}) г\./);

        my $y;
        my $m;
        my $d;;
        if ($start =~ /(\d{2}) (\w+) (\d{4})/) {
            $d = $1;
            $m = $month->{$2};
            $y = $3; 
        } else {
            next;
        }

        #print "\n\tGET ".$event->{'link'};

        my $re = $ua->get($event->{'link'});
        my $ce = $re->decoded_content();
        my $ev = HTML::TreeBuilder->new_from_content( $ce );

        my @tms = $ev->look_down(class => 'time');

        next if (scalar(@tms) == 0);

        $tms[0]->as_text() =~ /(\d+)\:(\d+)/;

        my $h  = $1;
        my $mi = $2;

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

    return $events;
}

# MAIN
print "\nGRAB REDKASSA";
print "\n************************************";

# PARAM
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# Get Last Page
my $events = grabEvents();

print "\nGOT ".scalar(keys %$events)." EVENTS";

saveProviderEvents($events, 6, $d); # 6 = REDKASSA 

