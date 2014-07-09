#!/usr/bin/perl

use utf8;

use strict;
use warnings;

use DateTime;
use Encode;
use Data::Dumper;
use JSON;
use YAML;
use DBI;

binmode STDOUT, ':utf8';
$|++;

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

sub getTags {
    my ($d) = @_;

    my $sql = "select `id`, `name` from `Tag`";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $tags = { };
    
    while ( my ($id, $name) = $sth->fetchrow_array() ) {
        $tags->{'i_n'}{$id} = $name;
        $tags->{'n_i'}{$name} = $id;
    }

    return $tags;
}

sub getProviders {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `link` from `Provider`";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $providers = { };
    
    while ( my ($id, $name, $link) = $sth->fetchrow_array() ) {
        $providers->{$id} = { 
            'name' => $name,
            'link' => $link
        };
    }

    return $providers;
}

sub getInternalEvents {
    my ($d, $providers) = @_;

    my $sql = "select 
        `id`, 
        `name`, 
        `url_name`, 
        `artists`, 
        `tags`, 
        `catalog_rate`, 
        `place`,
        `start` 
    from `InternalEvent` where status = 1";

    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };
    
    while ( my ($id, $name, $url_name, $artists, $tags, $catalog_rate, $place, $start) = $sth->fetchrow_array() ) {
        $events->{$id}{'name'} = $name;
        $events->{$id}{'url_name'} = $url_name ? $url_name : '';
        $events->{$id}{'tags'} = $tags ? $tags : '';
        $events->{$id}{'catalog_rate'} = $catalog_rate ? $catalog_rate : 0;
        $events->{$id}{'start'} = $start;

        # Fetch artists
        my $sth2;

        if ($artists) {
            $sql = "select `id`, `name`, `tags` from `Artist` where id in ($artists)";
            $sth2 = $d->prepare($sql);
            $sth2->execute();

            while ( my @artist = $sth2->fetchrow_array() ) {
                my $aid = $artist[0];
                $events->{$id}{'artists'}{$aid}{'name'} = $artist[1];
                $events->{$id}{'artists'}{$aid}{'tags'} = $artist[2];
            }
        }

        # Fetch palace
        $sql = "select `id`, `name`, `address`, `keywords`, `metro`, `phone`, `url`, `latitude`, `longitude`, `zoom` from `Place` where id = $place";
        $sth2 = $d->prepare($sql);
        $sth2->execute();

        my ($place_id, $place_name, $address, $place_keywords, $metro, $phone, $url, $latitude, $longitude, $zoom) = $sth2->fetchrow_array();

        $events->{$id}{'place'} = encode_json({
            'id' => $place_id,
            'name' => $place_name,
            'address' => $address,
            'keywords' => $place_keywords,
            'metro' => $metro,
            'phone' => $phone,
            'url' => $url,
            'latitude' => $latitude,
            'longitude' => $longitude,
            'zoom' => $zoom,
        });

        Encode::_utf8_on( $events->{$id}{'place'} );

        # Fetch tickets
        my $tickets = { };

        $sql = "select `provider_id` from `InternalProvider` where internal_id = $id";
        $sth2 = $d->prepare($sql);
        $sth2->execute();

        while ( my ($provider_id) = $sth2->fetchrow_array() ) {
            $sql = "select `link`, `provider` from `ProviderEvent` where id = $provider_id and status = 1";
            my $sth3 = $d->prepare($sql);
            $sth3->execute();
             
            my ($link, $provider) = $sth3->fetchrow_array();
            
            next if (!$link || !$provider); 

            $sql = "select `id`, `sector`, `price_min`, `price_max` from `Ticket` where provider_event = $provider_id and status = 1";
            my $sth4 = $d->prepare($sql);
            $sth4->execute();

            while ( my ($ticket_id, $sector, $price_min, $price_max) = $sth4->fetchrow_array() ) {
                $tickets->{$ticket_id} = {
                    'provider_id'   => $provider_id,
                    'link'          => $link,
                    'provider'      => $provider,
                    'provider_name' => $providers->{$provider}{'name'},
                    'sector'        => $sector,
                    'price_min'     => $price_min,
                    'price_max'     => $price_max,
                };
            }
        }

        $events->{$id}{'tickets'} = $tickets; 
    }

    return $events;
}

sub getCurrentIndex {
    my ($d) = @_;

    my $sql = "select 
        `internal_id`, 
        `name`, 
        `url_name`, 
        `artists`, 
        `tags`, 
        `artists_tags`, 
        `catalog_rate`, 
        `place`, 
        `start`,
        `tickets`
    from `ActualInternalIndex`";

    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };
    
    while ( my ($internal_id, $name, $url_name, $artists, $tags, $artists_tags, $catalog_rate, $place, $start, $tickets) = $sth->fetchrow_array() ) {
        $tags = $tags ? $tags : '';
        $catalog_rate = $catalog_rate ? $catalog_rate : 0;
        $url_name = $url_name ? $url_name : '';
        $tickets = $tickets ? $tickets : '';

        # INDEX CHECKSTRING (IDX STR)
        $events->{ $internal_id } 
            = join('|', ( $internal_id, $name, $url_name, $artists, $tags, $artists_tags, $catalog_rate, $place, $start, $tickets ));
    }

    return $events;
}

# MAIN
print "\nMAKE INTERNAL INDEX";
print "\n************************************";

my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");
$d->{'mysql_enable_utf8'} = 1;

my $tags_hash = getTags($d);
my $providers = getProviders($d);

my $internal_events = getInternalEvents($d, $providers);
my $curr_index = getCurrentIndex($d);

# Delete from index
foreach my $id (keys $curr_index) {
    if (!$internal_events->{$id}) {
        my $sql = "delete from `ActualInternalIndex` where internal_id = ?";
        my $sth = $d->prepare($sql);

        $sth->execute(
            $id
        ); 

        print "\nDELETE $id EVENT";
    }
}

# Add and update elements in index
foreach my $id (keys %$internal_events) {
    my $name         = $internal_events->{$id}{'name'};
    my $url_name     = $internal_events->{$id}{'url_name'};
    my $catalog_rate = $internal_events->{$id}{'catalog_rate'};
    my $tags_str     = $internal_events->{$id}{'tags'};
    my $start        = $internal_events->{$id}{'start'};
    my $place        = $internal_events->{$id}{'place'};
    my $tickets      = $internal_events->{$id}{'tickets'};

    # Process artists
    my $artists_arr  = [ ];
    my $artists_tags = { };

    if ($internal_events->{$id}{'artists'}) {
        foreach my $aid (keys $internal_events->{$id}{'artists'}) {
            my $artist_name = $internal_events->{$id}{'artists'}{$aid}{'name'};
            push($artists_arr, $artist_name); 

            my @artist_tags = split(',', $internal_events->{$id}{'artists'}{$aid}{'tags'});

            foreach (@artist_tags) {
                $artists_tags->{$_}++;
            }
        }
    }

    my $artists_str = join(',', @$artists_arr);
    my $artists_tags_str = join(',', keys %$artists_tags);

    # Preprocess tags
    my @tags = split(',', $tags_str);
    my @tags_list = scalar(@tags) > 0 ? @tags : keys %$artists_tags; 
    my @tags_names_list = ();

    foreach my $tid (@tags_list) {
        push(@tags_names_list, $tags_hash->{'i_n'}{$tid}); 
    }

    my $tags_names_str = join(',', @tags_names_list);

    # Preprocess tickets
    my $tickets_str = $tickets ? encode_json($tickets) : '';
    Encode::_utf8_on( $tickets_str );

    # INTERNAL EVENT CHECKSTRING (CHK STR) 
    my $check_str = join('|', ( $id, $name, $url_name, $artists_str, $tags_str, $artists_tags_str, $catalog_rate, $place, $start, $tickets_str ));

    # Save data
    if (!$curr_index->{$id}) {
        # Insert new element to index 
        my $sql = "insert into `ActualInternalIndex` 
            (`internal_id`, `name`, `url_name`, `artists`, `tags`, `artists_tags`, `catalog_rate`, `place`, `start`, `tags_names`, `tickets`) 
            values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        my $sth = $d->prepare($sql);

        $sth->execute(
            $id,
            $name, 
            $url_name, 
            $artists_str,
            $tags_str,
            $artists_tags_str, 
            $catalog_rate,
            $place,
            $start,
            $tags_names_str,
            $tickets_str
        ); 

        print "\nINSERT $id EVENT";

    } elsif ($curr_index->{$id} ne $check_str) {
        print "\nUPDATE $id EVENT";
        #print "\n\tIDX STR: ".$curr_index->{$id};
        #print "\n\tCHK STR: $check_str";

        # Update in index
        my $sql = "update `ActualInternalIndex` 
            set `name` = ?, `url_name` = ?, `artists` = ?, `tags` = ?, `artists_tags` = ?, `catalog_rate` = ?, `place` = ?, `start` = ?, `tags_names` = ?, `tickets` = ? 
            where internal_id = '$id'";
        my $sth = $d->prepare($sql);

        $sth->execute(
            $name, 
            $url_name, 
            $artists_str,
            $tags_str, 
            $artists_tags_str, 
            $catalog_rate,
            $place,
            $start,
            $tags_names_str,
            $tickets_str
        ); 
    }
}

