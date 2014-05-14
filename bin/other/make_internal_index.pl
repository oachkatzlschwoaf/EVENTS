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

sub getInternalEvents {
    my ($d) = @_;

    my $sql = "select `id`, `name`, `artists`, `tags` from `InternalEvent` where status = 1";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };
    
    while ( my @row = $sth->fetchrow_array() ) {
        my $id = $row[0];
        
        $events->{$id}{'name'} = $row[1];
        $events->{$id}{'tags'} = $row[3];

        # Fetch artists
        $sql = "select `id`, `name`, `tags` from `Artist` where id in (".$row[2].")";
        my $sth2 = $d->prepare($sql);
        $sth2->execute();

        while ( my @artist = $sth2->fetchrow_array() ) {
            my $aid = $artist[0];
            $events->{$id}{'artists'}{$aid}{'name'} = $artist[1];
            $events->{$id}{'artists'}{$aid}{'tags'} = $artist[2];
        }
    }

    return $events;
}

sub getCurrentIndex {
    my ($d) = @_;

    my $sql = "select `internal_id`, `name`, `artists`, `tags`, `artists_tags` from `ActualInternalIndex`";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $events = { };
    
    while ( my @row = $sth->fetchrow_array() ) {
        my $tags = $row[3] ? $row[3] : '';
        $events->{ $row[0] } = join('|', ( $row[1], $row[2], $tags, $row[4] ));
    }

    return $events;
}

# MAIN
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");
$d->{'mysql_enable_utf8'} = 1;

my $internal_events = getInternalEvents($d);
my $curr_index = getCurrentIndex($d);

# Delete from index
foreach my $id (keys $curr_index) {
    if (!$internal_events->{$id}) {
        my $sql = "delete from `ActualInternalIndex` where internal_id = ?";
        my $sth = $d->prepare($sql);

        $sth->execute(
            $id
        ); 

        print "$id event delete from index";
    }
}

# Add and update elements in index
foreach my $id (keys %$internal_events) {
    my $name = $internal_events->{$id}{'name'};
    my $artists_arr = [];
    my $tags = { };

    # Process artists
    foreach my $aid (keys $internal_events->{$id}{'artists'}) {
        my $artist_name = $internal_events->{$id}{'artists'}{$aid}{'name'};
        push($artists_arr, $artist_name); 

        my @artist_tags = split(',', $internal_events->{$id}{'artists'}{$aid}{'tags'});

        foreach (@artist_tags) {
            $tags->{$_}++;
        }
    }

    # Process tags
    my $etags_str = $internal_events->{$id}{'tags'} ? $internal_events->{$id}{'tags'} : "";

    my @etags;
    if ($internal_events->{$id}{'tags'}) {
        @etags = split(',', $internal_events->{$id}{'tags'});
    }

    # Prepare data
    my $artists_str = join(',', @$artists_arr);
    my $tags_str = join(',', keys %$tags);

    if (scalar(@etags) > 0) {
        $tags_str = join(',', @etags);
    }

    my $check_str = join('|', ( $name, $artists_str, $etags_str, join(',', keys %$tags)));

    # Save data
    if (!$curr_index->{$id}) {
        # Insert new element to index 
        my $sql = "insert into `ActualInternalIndex` (`internal_id`, `name`, `artists`, `artists_tags`) values(?, ?, ?, ?)";
        my $sth = $d->prepare($sql);

        $sth->execute(
            $id,
            $name, 
            $artists_str,
            $tags_str, 
        ); 

        print "\n$id event added in index";

    } elsif ($curr_index->{$id} ne $check_str) {
        print "\n".$curr_index->{$id};
        print "\n$check_str";


        # Update in index
        my $sql = "update `ActualInternalIndex` set `name` = ?, `artists` = ?, `tags` = ?, `artists_tags` = ? where internal_id = ?";
        my $sth = $d->prepare($sql);

        $sth->execute(
            $name, 
            $artists_str,
            join(',', @etags), 
            join(',', keys %$tags), 
            $id
        ); 

        print "\n$id event updated in index";
    }
}

