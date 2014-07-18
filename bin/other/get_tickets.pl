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
use List::Util qw( min max );
use JSON;
use YAML;
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);

binmode STDOUT, ':utf8';

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

sub getProviderEvents {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `date`, `start`, `place_text`, `place`, `provider`, `provider_id`, `link` from `ProviderEvent` where status not in (2, 5)";
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

sub grabPonominalu {
    my ($e) = @_;

    my $url = 'http://www.ponominalu.ru/event/'.$e->{'provider_id'};

    my $ua = LWP::UserAgent->new();
    my $r = $ua->get($url);
    my $c = $r->decoded_content();
    
    my $t = HTML::TreeBuilder->new();
    $t->ignore_unknown(0);
    $t->parse( $c );
    $t->eof();

    my $agg = {};

    if ($c =~ /sector\.setPrices\(\[(.*?)\]\)/) {

        my @prices = split(/,/, $1);
        my $price_min = min @prices;
        my $price_max = max @prices;

        my @h4 = $t->look_down(_tag => 'h4');
        my $sector = $h4[0]->as_text();

        $agg->{$sector}{'price_max'} = $price_max;
        $agg->{$sector}{'price_min'} = $price_min;

    } else {
        my @trs = $t->look_down(class => 'thleft');

        my @prices = $c =~ m/(.*) &#8399;/g; 

        my $i = 0;
        foreach my $tr (@trs) {
            $i++;
            next if ($i == 1);

            my $sector = $tr->as_text();
            my $price_min = undef;
            my $price_max = undef;

            my $price = trim($prices[ $i - 2 ]);

            if ($price =~ /(\d+) - (\d+)/) {
                $price_min = $1;
                $price_max = $2;
            } else {
                $price_min = $price;
                $price_max = $price;
            }

            $agg->{$sector}{'price_max'} = $price_max;
            $agg->{$sector}{'price_min'} = $price_min;
        }
    }

    return $agg;
}

sub grabParter {
    my ($e) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = $e->{'link'};

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $agg = {};

    my $t = HTML::TreeBuilder->new_from_content( $c );

    my @trs = $t->look_down(class => 'lastDiscountLevelRow');

    my $i = 0;
    foreach my $tr (@trs) {

        # Sector
        my @td_sector = $tr->look_down(class => 'single-rowspan priceCategory');
        my $sector = $td_sector[0]->as_text;

        # Price 
        my @td_price = $tr->look_down(class => 'single-rowspan price');
        my $price = $td_price[0]->as_text;

        $price =~ s/руб\.//;
        $price =~ s/,//g;
        $price =~ s/\s//g;
        $price /= 100;

        if (!$agg->{$sector}{'price_min'} || $agg->{$sector}{'price_min'} >= $price) {
            $agg->{$sector}{'price_min'} = $price;
        }

        if (!$agg->{$sector}{'price_max'} || $agg->{$sector}{'price_max'} < $price) {
            $agg->{$sector}{'price_max'} = $price;
        }
    }

    return $agg;
}

sub grabTicketland {
    my ($e) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = $e->{'link'};

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $agg = {};

    my $t = HTML::TreeBuilder->new_from_content( $c );

    my @table = $t->look_down(class => 'perform');
    
    return $agg if (scalar(@table) == 0);

    my @links = $table[0]->look_down(_tag => 'a');

    my $l = pop @links;
    my $path = $l->attr('href');

    $url = 'http://www.ticketland.ru/'.$path;
    $r = $ua->get($url);
    $c = $r->decoded_content();

    my ($eid, $oid, $sec);

    if ($c =~ /performance = (\d+);/) {
        $eid = $1;
    }

    if ($c =~ /objId = (\d+);/) {
        $oid = $1;
    }

    if ($c =~ /sections = (.+);/) {
        $sec = $1;
    }

    if ($eid && $oid && $sec) { 
        my $jsec = decode_json($sec);

        if (ref $jsec eq 'ARRAY') {
            $r = $ua->get('http://www.ticketland.ru/hallview/map/'.$eid.'/?webObjId='.$oid);
            $c = $r->decoded_content();

            my $t = HTML::TreeBuilder->new();
            $t->ignore_unknown(0);
            $t->parse( $c );
            $t->eof();

            my @ps = $t->look_down(class => 'place free');

            foreach my $p (@ps) {
                my $sector = $p->attr('data-section-name');
                my $price = $p->attr('data-price');

                if ($sector && $price && $price > 0) {
                    if (!$agg->{$sector}{'price_min'} || $agg->{$sector}{'price_min'} >= $price) {
                        $agg->{$sector}{'price_min'} = $price;
                    }

                    if (!$agg->{$sector}{'price_max'} || $agg->{$sector}{'price_max'} < $price) {
                        $agg->{$sector}{'price_max'} = $price;
                    }
                }
            }
        } elsif (ref $jsec eq 'HASH') {
            foreach my $key (keys %$jsec) {
                $r = $ua->get('http://www.ticketland.ru/hallview/map/'.$eid.'/'.$key.'/?webObjId='.$oid);
                $c = $r->decoded_content();

                my $t = HTML::TreeBuilder->new();
                $t->ignore_unknown(0);
                $t->parse( $c );
                $t->eof();

                my @ps = $t->look_down(class => 'place free');

                foreach my $p (@ps) {
                    my $sector = $p->attr('data-section-name');
                    my $price = $p->attr('data-price');

                    if ($sector && $price && $price > 0) {
                        if (!$agg->{$sector}{'price_min'} || $agg->{$sector}{'price_min'} >= $price) {
                            $agg->{$sector}{'price_min'} = $price;
                        }

                        if (!$agg->{$sector}{'price_max'} || $agg->{$sector}{'price_max'} < $price) {
                            $agg->{$sector}{'price_max'} = $price;
                        }
                    }
                }
            }
        }
    }

    return $agg;
}

sub grabRedkassa {
    my ($e) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = $e->{'link'};

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $agg = {};

    my $t = HTML::TreeBuilder->new_from_content( $c );

    my @elements = $t->look_down(class => 'tickets');
    my $table = $elements[0];

    if ($table) {
        my @trs = $table->look_down(_tag => 'tr');

        my $i = 0;
        foreach my $tr (@trs) {
            my $sector;
            my $price;
            
            # Sector
            my @ss = $tr->look_down(class => 'col2');

            if (scalar(@ss) > 0) {
                $sector = $ss[0]->as_text;
            }

            # Price 
            my @ps = $tr->look_down(class => 'col5');

            if (scalar(@ps) > 0) {
                $ps[0]->as_text =~ /(\d+)/;

                $price = $1 if ($1);
            }

            if ($sector && $price) {
                if (!$agg->{$sector}{'price_max'} || $agg->{$sector}{'price_max'} < $price) {
                    $agg->{$sector}{'price_max'} = $price;
                }

                if (!$agg->{$sector}{'price_min'} || $agg->{$sector}{'price_min'} > $price) {
                    $agg->{$sector}{'price_min'} = $price;
                }
            }
        }
    }

    return $agg;
}


sub grabBiletmarket {
    my ($e) = @_;

    my $ua = LWP::UserAgent->new();
    my $url = $e->{'link'};

    my $r = $ua->get($url);
    my $c = $r->decoded_content();

    my $agg = {};

    my $t = HTML::TreeBuilder->new_from_content( $c );

    my @elements = $t->look_down(class => 'table');
    my $table = $elements[0];

    if ($table) {
        my @trs = $table->look_down(_tag => 'tr');

        my $i = 0;
        foreach my $tr (@trs) {
            $i++;
            next if ($i == 1 || $i == scalar(@trs));

            my $sector;
            my $price;

            # Sector
            my @ss = $tr->look_down(_tag => 'th');

            if (scalar(@ss) > 0) {
                $sector = $ss[0]->as_text;
            }

            # Price 
            my @ps = $tr->look_down(_tag => 'td');

            if (scalar(@ps) > 0) {
                $ps[1]->as_text =~ /(\d+)/;
                $price = $1 if ($1);
            }

            if ($sector && $price) {
                if (!$agg->{$sector}{'price_max'} || $agg->{$sector}{'price_max'} < $price) {
                    $agg->{$sector}{'price_max'} = $price;
                }

                if (!$agg->{$sector}{'price_min'} || $agg->{$sector}{'price_min'} > $price) {
                    $agg->{$sector}{'price_min'} = $price;
                }
            }
        }
    }

    return $agg;
}


sub getTickets {
    my ($events) = @_;
    
    my $event_tickets = {};
    foreach my $e_id (keys %$events) {
        my $e = $events->{$e_id};

        print "\n\tGRAB TICKETS $e_id (PROVIDER: ".$e->{'provider'}."): ".$e->{'link'};

        my $agg_tickets = { };
        if ($e->{'provider'} == 1) {
            $agg_tickets = grabKassir($e);
        } elsif ($e->{'provider'} == 2) {
            $agg_tickets = grabConcert($e);
        } elsif ($e->{'provider'} == 3) {
            $agg_tickets = grabPonominalu($e);
        } elsif ($e->{'provider'} == 4) {
            $agg_tickets = grabParter($e);
        } elsif ($e->{'provider'} == 5) {
            $agg_tickets = grabTicketland($e);
        } elsif ($e->{'provider'} == 6) {
            $agg_tickets = grabRedkassa($e);
        } elsif ($e->{'provider'} == 7) {
            $agg_tickets = grabBiletmarket($e);
        } else {
            next;
        }

        print "\n\tFOUND ".scalar(keys %$agg_tickets)." tickets";

        next if (!$agg_tickets || scalar(keys %$agg_tickets) == 0);
        $event_tickets->{ $e_id } = $agg_tickets;
    }

    return $event_tickets;
}

sub saveTicket {
    my ($d, $event_id, $sector, $min, $max) = @_;

    my $dt = DateTime->now();

    my $sql = "insert into `Ticket` (`provider_event`, `sector`, `price_min`, `price_max`, `status`, `secret`, `created_at`) 
        values(?, ?, ?, ?, ?, ?, ?)";
    my $sth = $d->prepare($sql);

    my $hash_str = "$event_id-$sector-$min-$max-".rand(1000);
    my $hash = md5_hex($hash_str);

    $sth->execute(
        $event_id,
        $sector,
        $min,
        $max,
        1, 
        $hash,
        $dt->ymd().' '.$dt->hms(),
    ); 

    print "\n\t\tNEW TICKET ($sector, $min, $max)";
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

    print "\n\t\tUPDATE TICKET ($sector, $min, $max)";
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

    print "\n\t\tSWITCH TICKET OFF ($sector)";
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
print "\nGET TICKETS FOR PROVIDER EVENTS";
print "\n************************************";

my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

# 1. Get all active provider events
my $provider_events = getProviderEvents($d);

print "\nGET ".scalar(keys %$provider_events)." PROVIDER EVENTS";

# 2. Get tickets for them
my $tickets = getTickets($provider_events);

print "\n\nPROCESS TICKETS";

my $save_stat = { };

foreach my $e_id (keys %$provider_events) {
    print "\n\tEVENT $e_id";

    my $event = $provider_events->{$e_id};
    
    my $ex_tickets = getExistsTicket($d, $e_id);

    # Process grabbed tickets
    my $new_tickets = $tickets->{$e_id};

    foreach my $sector (keys %$new_tickets) {
        my $min = $new_tickets->{$sector}{'price_min'};
        my $max = $new_tickets->{$sector}{'price_max'};

        next if (!$sector || !$min || !$max);

        $sector = trim($sector);

        if (defined($ex_tickets->{$sector}) && scalar( keys %{ $ex_tickets->{$sector} } ) > 0) {
            $save_stat->{'update'}{ $event->{'provider'} }++;
            updateTicket($d, $e_id, $sector, $min, $max);
            delete( $ex_tickets->{$sector} );
        } else {
            $save_stat->{'save'}{ $event->{'provider'} }++;
            saveTicket($d, $e_id, $sector, $min, $max);
            delete( $ex_tickets->{$sector} );
        }
    }

    # Switch off non existed tickets
    foreach my $sector (keys %$ex_tickets) {
        $save_stat->{'off'}{ $event->{'provider'} }++;
        switchOffTicket($d, $e_id, $sector);
    }
}

# Save Report as Admin Action
my $dt = DateTime->now();

my $sql = "insert into `AdminAction` (`type`, `info`, `created_at`) 
    values(?, ?, ?)";
my $sth = $d->prepare($sql);
$sth->execute(
    5, # ACTION: TICKETS 
    JSON::encode_json($save_stat),
    $dt->ymd().' '.$dt->hms()
);
