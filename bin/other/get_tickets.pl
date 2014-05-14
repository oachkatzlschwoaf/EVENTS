#!/usr/bin/perl

use utf8;

use strict;
use warnings;

$|++;

use DateTime;
use Encode;
use Data::Dumper;
use LWP::Simple;
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

sub getProviderEvents {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `date`, `start`, `place_text`, `place`, `provider`, `provider_id`, `link` from `ProviderEvent` where status = '1'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };

    while ( my @row = $sth->fetchrow_array() ) {
        my $event = { };  
        
        $event->{'id'} = $row[0];
        $event->{'name'} = $row[1];
        $event->{'date'} = $row[2];
        $event->{'start'} = $row[3];
        $event->{'place_text'} = $row[4];
        $event->{'place'} = $row[5];
        $event->{'provider'} = $row[6];
        $event->{'provider_id'} = $row[7];
        $event->{'link'} = $row[8];

        $events->{ $event->{'id'} } = $event;
    }

    return $events;
}

sub grabKassir {
    my ($e) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = $e->{'link'};

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $agg = {};

    my $t = HTML::TreeBuilder->new_from_content( $c );

    my @elements = $t->look_down(class => 'event-general__scheme__table');
    my $table = $elements[0];

    if ($table) {
        my @trs = $table->look_down(_tag => 'tr');

        my $i = 0;
        foreach my $tr (@trs) {
            $i++;
            next if ($i == 1);

            my @tds = $tr->look_down(_tag => 'td');

            my $sector    = undef;
            my $price_min = undef;
            my $price_max = undef;
            my $j = 0;

            foreach my $td (@tds) {
                $j++;

                if ($j == 1) {
                    $sector = $td->as_text();
                } elsif ($j == 2) {
                    next if (!$sector);
                    my $p = $td->as_text();

                    if ($p =~ /(\d+) руб. — (\d+) руб./) {
                        $price_min = $1;
                        $price_max = $2;

                    } elsif ($p =~ /(\d+) руб./) {
                        $price_min = $1;
                        $price_max = $1;
                    }
                }

                if ($sector && $price_min && $price_max) {
                    if (!$agg->{$sector}{'price_max'} || $agg->{$sector}{'price_max'} < $price_max) {
                        $agg->{$sector}{'price_max'} = $price_max;
                    }

                    if (!$agg->{$sector}{'price_min'} || $agg->{$sector}{'price_min'} > $price_min) {
                        $agg->{$sector}{'price_min'} = $price_min;
                    }
                }
            }
        }
    }

    return $agg;
}

sub grabConcert {
    my ($e) = @_;

    my $url = 'http://www.concert.ru/Order.aspx?ActionID='.$e->{'provider_id'};

    my $ua = LWP::UserAgent->new();
    my $r = $ua->get($url);
    my $c = $r->decoded_content();
    
    my $t = HTML::TreeBuilder->new_from_content( $c );

    my $agg = {};

    my @trs = $t->look_down(class => 'tdNewDesign');

    my $i = 0;
    foreach my $tr (@trs) {
        $i++;

        my @tds = $tr->look_down(_tag => 'td');

        my $sector    = undef;
        my $price_min = undef;
        my $price_max = undef;
        my $j = 0;

        foreach my $td (@tds) {
            $j++;

            if ($j == 3) {
                $sector = $td->as_text();
            } elsif ($j == 5) {
                next if (!$sector);
                my $p = $td->as_text();

                if ($p =~ /(\d+)/) {
                    $price_min = $1;
                    $price_max = $1;
                }
            }

            if ($sector && $price_min && $price_max) {
                if (!$agg->{$sector}{'price_max'} || $agg->{$sector}{'price_max'} < $price_max) {
                    $agg->{$sector}{'price_max'} = $price_max;
                }

                if (!$agg->{$sector}{'price_min'} || $agg->{$sector}{'price_min'} > $price_min) {
                    $agg->{$sector}{'price_min'} = $price_min;
                }
            }
        }
    }

    return $agg;
}

sub getTickets {
    my ($events) = @_;
    
    my $event_tickets = {};
    my $i = 0;
    foreach my $e_id (keys %$events) {
        my $e = $events->{$e_id};

        print "\nGet tickets for $e_id (".$e->{'provider'}." ".$e->{'link'}.")";

        my $agg_tickets = { };
        if ($e->{'provider'} == 1) {
            $agg_tickets = grabKassir($e);
            print " found ".scalar(keys %$agg_tickets)." tickets";

        } elsif ($e->{'provider'} == 2) {
            $agg_tickets = grabConcert($e);

            print " found ".scalar(keys %$agg_tickets)." tickets";

        }

        next if (!$agg_tickets || scalar(keys %$agg_tickets) == 0);
        $event_tickets->{ $e_id } = $agg_tickets;

        $i++;
        #last if ($i > 1); # DEBUG 
    }

    return $event_tickets;
}

sub saveTicket {
    my ($d, $event_id, $sector, $min, $max) = @_;

    my $sql = "insert into `Ticket` (`provider_event`, `sector`, `price_min`, `price_max`, `status`) 
        values(?, ?, ?, ?, ?)";
    my $sth = $d->prepare($sql);

    $sth->execute(
        $event_id,
        $sector,
        $min,
        $max,
        1 # status
    ); 

    print " -> new ticket saved...";
}

sub updateTicket {
    my ($d, $event_id, $sector, $min, $max) = @_;

    my $sql = "update `Ticket` set price_min = ?, price_max = ?, status = ? where provider_event = ? and sector = ?";
    my $sth = $d->prepare($sql);

    $sth->execute(
        $min,
        $max,
        1,
        $event_id,
        $sector
    ); 

    print " -> ticket updated...";
}

sub switchOffTicket {
    my ($d, $event_id, $sector, $min, $max) = @_;

    my $sql = "update `Ticket` set status = ? where provider_event = ? and sector = ?";
    my $sth = $d->prepare($sql);

    $sth->execute(
        0,
        $event_id,
        $sector
    ); 

    print " -> ticket switched off...";
}

sub getExistsTicket {
    my ($d, $event_id) = @_;

    my $sql = "select `id`, `sector`, `price_min`, `price_max` from `Ticket` where provider_event = '$event_id'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $tickets = { };
    while ( my @row = $sth->fetchrow_array() ) {
        my $sector = $row[1];
        my $min    = $row[2];
        my $max    = $row[3];

        Encode::_utf8_on($sector);
        
        $tickets->{ $sector }{'price_min'} = $min;
        $tickets->{ $sector }{'price_max'} = $max;
    }
    
    return $tickets;
}

# MAIN
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# 1. Get all active provider events
my $provider_events = getProviderEvents($d);

print "\nGet ".scalar(keys %$provider_events)." events";

# 2. Get tickets for them
my $tickets = getTickets($provider_events);

print "\nProcess Tickets";

foreach my $e_id (keys %$provider_events) {
    print "\nEvent $e_id";
    
    my $ex_tickets = getExistsTicket($d, $e_id);

    # Process grabbed tickets
    my $new_tickets = $tickets->{$e_id};

    foreach my $sector (keys %$new_tickets) {
        my $min = $new_tickets->{$sector}{'price_min'};
        my $max = $new_tickets->{$sector}{'price_max'};

        if (defined($ex_tickets->{$sector}) && scalar( keys %{ $ex_tickets->{$sector} } ) > 0) {
            print "\n\t'$sector' update ticket"; 
            updateTicket($d, $e_id, $sector, $min, $max);
            delete( $ex_tickets->{$sector} );
        } else {
            print "\n\t'$sector' save new ticket"; 
            saveTicket($d, $e_id, $sector, $min, $max);
            delete( $ex_tickets->{$sector} );
        }
    }

    # Switch off non existed tickets
    foreach my $sector (keys %$ex_tickets) {
        print "\n\t'$sector' switch off";
        switchOffTicket($d, $e_id, $sector);
    }
}

