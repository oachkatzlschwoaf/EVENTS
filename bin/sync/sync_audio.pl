#!/usr/bin/perl

#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Data::Dumper;
use LWP::Simple;
use LWP::UserAgent;
use JSON;
use YAML;
use DBI;

$|++;

binmode STDOUT, ':utf8';

sub getConfig {
    return YAML::LoadFile("../../app/config/config.yml");
}

sub getParameters {
    return YAML::LoadFile("../../app/config/parameters.yml");
}

sub connectDb {
    my ($c) = @_;

    return DBI->connect(
        'dbi:mysql:'.$c->{'database_name'}.':'.$c->{'database_host'}.':'.$c->{'database_port'}, 
        $c->{'database_user'}, 
        $c->{'database_password'}
    );
}

sub requestVkApi {
    my ($method, $params, $c) = @_;

    my $url = $c->{'networks.vkontakte.api_url'}."/".$method;
    my $uri = URI->new($url);
    $uri->query_form($params);

    my $out = get($uri);
    my $json = decode_json($out);

    return $json;
}

sub getAudioList {
    my ($uid, $sk, $c) = @_;

    print "\n\tGet user $uid audio list";

    my $params = {
        'access_token' => $sk,
        'app_id'       => $c->{'networks.vkontakte.app_id'},
    };

    my $data = requestVkApi('audio.get', $params, $c);

    if ($data->{'error'}) {
        return;
    } else {
        print " -> done!";
        return $data->{'response'};
    }
}

sub getTopTags {
    my ($artist, $c) = @_;

    my $url = $c->{'lastfm_api_url'};

    my $params = {
        'method'  => 'artist.gettoptags',
        'api_key' => $c->{'lastfm_api_key'},
        'artist'  => $artist,
        'format'  => 'json',
        'autocorrect'  => '1',
    };

    my $uri = URI->new($url);
    $uri->query_form($params);
    
    my $out = get($uri);
    my $json = decode_json($out);

    my $tags = {}; 

    if (!$json->{'error'} && $json->{'toptags'}{'tag'}) {
        my $info = $json->{'toptags'}{'tag'};

        if (ref $info eq 'ARRAY') {
            foreach my $tag (@$info) {
                next if ($tag->{'count'} < 30);
                $tags->{ $tag->{'name'} }++;
            }
        }
    }

    return $tags;
}

sub analyzeTags {
    my ($list, $c) = @_;

    print "\n\tAnalyze tags";

    my $i = 0;
    my $user_tags = {};
    foreach my $a (@$list) {
        my $tags = getTopTags($a->{'artist'}, $c);
        
        foreach my $t (keys %$tags) {
            $user_tags->{ $t } += $tags->{$t};
        }
    }

    my $ret = { };
    foreach my $t (keys %$user_tags) {
        $ret->{$t} = $user_tags->{$t};
    }

    print " -> done!";

    return $ret;
}

sub syncDb {
    my ($d, $user_id, $network_list) = @_;

    print "\n\tSync user $user_id db";

    # Make hash
    my $network_hash = { };
    foreach my $t (@$network_list) {
        $network_hash->{ $t->{'artist'}.'+'.$t->{'title'} } = $t;
    }

    # Get Db Audio List
    my $changes = {};

    my $sql = "select `id`, `artist_id`, `artist`, `title` from `UserAudio` where user_id = '$user_id'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $db_hash = { };
    while ( my @row = $sth->fetchrow_array() ) {
        my $artist = $row[2];
        my $title  = $row[3];
        
        $db_hash->{ $artist.'+'.$title } = {
            'id'     => $row[0],
            'artist' => $artist,
            'title'  => $title,
        };
    }

    # To add
    foreach my $k (keys %$network_hash) {
        if (!$db_hash->{$k}) {
            my $t = $network_hash->{$k};

            my $sql = "insert into `UserAudio` (`user_id`, `artist`, `title`) values(?, ?, ?)";
            my $sth = $d->prepare($sql);

            $sth->execute(
                $user_id, 
                $t->{'artist'}, 
                $t->{'title'}, 
            ); 

            push( @{ $changes->{'add'} }, $t);
        }
    }

    # To delete
    foreach my $k (keys %$db_hash) {
        if (!$network_hash->{$k}) {
            my $t = $db_hash->{$k};
            my $id = $t->{'id'};

            my $sql = "delete from `UserAudio` where id = '$id'";
            my $sth = $d->prepare($sql);

            $sth->execute( ); 

            push( @{ $changes->{'delete'} }, $t);
        }
    }

    print " -> done!";
    return $changes;
}

sub updateSyncStatus {
    my ($d, $user_id, $status) = @_;

    my $sql = "update `Sync` set status = ? where user_id = ?";
    my $sth = $d->prepare($sql);

    $sth->execute(
        $status,
        $user_id, 
    ); 

    return;
}

sub saveTags {
    my ($d, $user_id, $tags) = @_;

    print "\n\tSave user $user_id tags";
    my $json = encode_json($tags);

    my $sql = "update `User` set tags = ? where id = ?";
    my $sth = $d->prepare($sql);

    $sth->execute(
        $json,
        $user_id, 
    ); 

    print " -> done!";

    return;
}

sub addTags {
    my ($tags, $add_tags) = @_;

    foreach my $t (keys %$add_tags) {
        $tags->{$t} += $add_tags->{$t};
    }

    return $tags;
}

sub deleteTags {
    my ($tags, $del_tags) = @_;

    foreach my $t (keys %$del_tags) {
        $tags->{$t} -= $del_tags->{$t};

        if ($tags->{$t} <= 0) {
            delete($tags->{$t});
        }
    }

    return $tags;
}

sub getUserTags {
    my ($d, $user_id) = @_;

    my $sql = "select `tags` from `User` where id = ?";
    my $sth = $d->prepare($sql);

    $sth->execute(
        $user_id, 
    ); 

    my @row = $sth->fetchrow_array();

    if (!$row[0]) {
        return { };
    } else {
        return decode_json($row[0]);
    }
}

sub getSync {
    my ($d, $sync_id) = @_;

    my $sql = "select `id`, `user_id`, `network`, `network_id`, `auth_info`, `status`, `last_sync` from `Sync` where id = ?";
    my $sth = $d->prepare($sql);
    $sth->execute(
        $sync_id,
    );

    if (my @row = $sth->fetchrow_array()) {
        my $json = decode_json( $row[4] );

        return {
            'id' => $row[0],
            'user_id' => $row[1],
            'network' => $row[2],
            'network_id' => $row[3],
            'access_token' => $json->{'access_token'},
        };
    } else {
        return;
    }
}

# MAIN
my $params = getParameters();
$params = $params->{'parameters'}; 

my $config = getConfig();
$config = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");
$d->{'mysql_enable_utf8'} = 1;

if (my $sync_id = $ARGV[0]) {
    print "Look for sync $sync_id";
    my $to_sync = getSync($d, $sync_id);

    if ($to_sync) {
        print "\nStart process sync $sync_id";

        # Get Network Audio List
        updateSyncStatus($d, $to_sync->{'user_id'}, 2); # sync audio list
        my $audio_list = getAudioList($to_sync->{'user_id'}, $to_sync->{'access_token'}, $config);

        if (!$audio_list) {
            updateSyncStatus($d, $to_sync->{'user_id'}, 4); # sync error 
            die "\nERROR: Sync $sync_id cannot get audio list";
        }

        # Sync DB
        updateSyncStatus($d, $to_sync->{'user_id'}, 3); # sync tags 
        my $diff = syncDb($d, $to_sync->{'user_id'}, $audio_list);

        # Analyse tags to add
        my $user_tags = getUserTags($d, $to_sync->{'user_id'});

        my $add_tags = analyzeTags($diff->{'add'}, $config);
        $user_tags = addTags($user_tags, $add_tags);

        my $del_tags = analyzeTags($diff->{'delete'}, $config);
        $user_tags = deleteTags($user_tags, $del_tags);

        saveTags($d, $to_sync->{'user_id'}, $user_tags);

        updateSyncStatus($d, $to_sync->{'user_id'}, 1); # sync done 
        print "\nSync $sync_id done";
    }
}
