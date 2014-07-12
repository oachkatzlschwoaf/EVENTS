#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Data::Dumper;
use Encode;
use Parallel::ForkManager;
use Proc::Daemon;
use LWP::UserAgent;
use Getopt::Long;
use YAML;
use DBI;
use JSON;
use DateTime;

$|++;

binmode STDOUT, ':utf8';
my $MAX_PROCESSES = 50;

sub getConfig {
    return YAML::LoadFile("../app/config/config.yml");
}

sub getParameters {
    return YAML::LoadFile("../app/config/parameters.yml");
}

sub connectDb {
    my ($c) = @_;

    my $d = DBI->connect(
        'dbi:mysql:'.$c->{'database_name'}.':'.$c->{'database_host'}.':'.$c->{'database_port'}, 
        $c->{'database_user'}, 
        $c->{'database_password'},
    );

    $d->do("SET NAMES 'utf8'");
    $d->{'mysql_enable_utf8'} = 1;

    return $d;
}

sub whatSync {
    my ($d) = @_;

    my $sql = "select `id`, `user_id`, `network`, `network_id`, `auth_info`, `status`, `last_sync` from `Sync` where status = 0 limit $MAX_PROCESSES";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $list = [ ];

    while ( my @row = $sth->fetchrow_array() ) {
        my ($id, $user_id) = @row;

        my $json = decode_json( $row[4] );

        push(@$list, {
            'id' => $row[0],
            'user_id' => $row[1],
            'network' => $row[2],
            'network_id' => $row[3],
            'access_token' => $json->{'access_token'},
        });
    }

    return $list;
}

sub cleanWord {
    my ($w) = @_;

    Encode::_utf8_on($w);
    $w = lc($w);
    $w =~ s/[\"\'\(\)]//g;
    $w =~ s/^\s+//;
    $w =~ s/\s+$//;

    return $w;
}

sub requestVkApi {
    my ($method, $params, $c) = @_;

    my $url = $c->{'networks.vkontakte.api_url'}."/".$method;
    my $uri = URI->new($url);
    $uri->query_form($params);

    my $ua = LWP::UserAgent->new();
    my $r = $ua->get($uri);
    my $json = decode_json( $r->decoded_content() );

    return $json;
}

sub getAudioList {
    my ($uid, $sk, $c, $FH) = @_;

    print $FH "\n\tUID $uid: GET PLAYLIST... ";

    my $params = {
        'access_token' => $sk,
        'app_id'       => $c->{'networks.vkontakte.app_id'},
    };

    my $data = requestVkApi('audio.get', $params, $c);

    if ($data->{'error'}) {
        return;
    } else {
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
    
    my $ua = LWP::UserAgent->new();
    my $r = $ua->get($uri);

    my $json = {}; 
    eval {
        $json = decode_json( $r->decoded_content() );
    };

    if ($@) {
        return {};
        warn $@;
    }

    my $tags = {}; 
    if (!$json->{'error'} && $json->{'toptags'}{'tag'}) {
        my $info = $json->{'toptags'}{'tag'};

        if (ref $info eq 'ARRAY') {
            foreach my $tag (@$info) {
                next if ($tag->{'count'} < 30);
                $tags->{ $tag->{'name'} } += $tag->{'count'};
            }
        }
    }

    return $tags;
}

sub analyzeTags {
    my ($d, $user_id, $c, $list, $FH) = @_;

    print $FH "\n\tUID $user_id: ANALYZE TAGS";

    my $untagged = 0;
    foreach my $id (keys %$list) {
        my $info = $list->{$id};

        if (!$info->{'tags'}) {
            $untagged++;
        }
    }

    updateAdditional($d, $user_id,
        { 'untagged' => $untagged, 'processed' => 0 }
    );

    my $i = 0;
    foreach my $id (keys %$list) {
        my $info = $list->{$id};

        if (!$info->{'tags'}) {
            
            my $tags = getTopTags($info->{'clean_artist'}, $c);

            my $tags_str = lc(encode_json($tags));

            my $sql = "update `UserAudioArtist` set `tags` = ? where `id` = ?";
            my $sth = $d->prepare($sql);

            $sth->execute(
                $tags_str,
                $id, 
            ); 

            $i++;
            updateAdditional($d, $user_id,
                { 'processed' => $i }
            );
        }
    }
}

sub syncAudioDb {
    my ($d, $user_id, $network_list, $FH) = @_;

    print $FH "\n\tUID $user_id: SYNC DB PLAYLIST";

    # Make hash
    my $network_hash = { };
    foreach my $t (@$network_list) {
        $network_hash->{ $t->{'artist'}.'+'.$t->{'title'} } = $t;
    }

    # Get Db Audio List
    my $changes = {};

    my $sql = "select `id`, `artist_id`, `artist`, `title`, `tags` from `UserAudio` where user_id = '$user_id'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $db_hash = { };
    while ( my ($id, $artist_id, $artist, $title, $tags) = $sth->fetchrow_array() ) {
        $db_hash->{ $artist.'+'.$title } = {
            'id'     => $id,
            'artist' => $artist,
            'title'  => $title,
        };
    }

    # If no playlist yet in db - set first time
    if (scalar(keys $db_hash) == 0) {
        updateAdditional($d, $user_id,
            { 'first_time' => 1 }
        );
    } else {
        updateAdditional($d, $user_id,
            { 'first_time' => 0 }
        );
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

            print $FH "\n\t\tUID $user_id: ADD AUDIO '$k'";
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

            print $FH "\n\t\tUID $user_id: DELETE AUDIO '$k'";
        }
    }
}

sub syncArtistDb {
    my ($d, $user_id, $list, $FH) = @_;

    print $FH "\n\tUID $user_id: SYNC ARTISTS";

    my $artists = { };
    foreach my $aid (keys %$list) {
        my $audio = $list->{$aid};
        my $artist = $audio->{'artist'};
        my $clean_artist = cleanWord($artist);

        $artists->{ $clean_artist }{'artist'} = $artist;
        $artists->{ $clean_artist }{'count'}++;
    }

    my $sql = "select `clean_artist`, `count` from `UserAudioArtist` where user_id = '$user_id'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $db_artists = { };
    while ( my ($clean_artist, $count) = $sth->fetchrow_array() ) {
        $db_artists->{ $clean_artist } = $count;
    }

    foreach my $clean_artist (keys %$db_artists) {
        if (!$artists->{$clean_artist}) {
            # Delete
            my $sql = "delete from `UserAudioArtist` where `clean_artist` = ? and `user_id` = ?";
            my $sth = $d->prepare($sql);

            $sth->execute(
                $clean_artist, 
                $user_id, 
            ); 

            print $FH "\n\tUID $user_id: DELETE ARTIST '$clean_artist'";

        } elsif ($db_artists->{$clean_artist} != $artists->{$clean_artist}{'count'}) {
            my $artist = $artists->{$clean_artist}{'artist'};
            my $count = $artists->{$clean_artist}{'count'};

            # Update
            my $sql = "update `UserAudioArtist` set `count` = ? where `clean_artist` = ? and `user_id` = ?";
            my $sth = $d->prepare($sql);

            $sth->execute(
                $count, 
                $clean_artist,
                $user_id, 
            ); 

            print $FH "\n\tUID $user_id: UPDATE ARTIST '$clean_artist' ($count)";
        }
    }

    foreach my $clean_artist (keys %$artists) {
        if (!$db_artists->{$clean_artist}) {
            my $artist = $artists->{$clean_artist}{'artist'};
            my $count = $artists->{$clean_artist}{'count'};

            # Add
            my $sql = "insert into `UserAudioArtist` (`user_id`, `artist`, `clean_artist`, `count`) values(?, ?, ?, ?)";
            my $sth = $d->prepare($sql);

            $sth->execute(
                $user_id, 
                $artist, 
                $clean_artist, 
                $count, 
            ); 

            print $FH "\n\t\tUID $user_id: ADD ARTIST '$artist'";
        }
    }
}

sub getUserAudio {
    my ($d, $user_id) = @_;

    print "\n\tUID $user_id: GET PLAYLIST... ";

    my $sql = "select `id`, `artist_id`, `artist`, `title`, `tags` from `UserAudio` where user_id = '$user_id'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $audio = { };
    while ( my ($id, $artist_id, $artist, $title, $tags) = $sth->fetchrow_array() ) {
        $audio->{ $id } = {
            'artist' => $artist,
            'title'  => $title,
            'tags'   => $tags,
        };
    }

    return $audio;
}

sub getUserAudioArtist {
    my ($d, $user_id, $FH) = @_;

    print $FH "\n\tUID $user_id: GET ARTISTS... ";

    my $sql = "select `id`, `artist`, `clean_artist`, `tags`, `count` from `UserAudioArtist` where user_id = '$user_id'";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $audio = { };
    while ( my ($id, $artist, $clean_artist, $tags, $count) = $sth->fetchrow_array() ) {
        $audio->{ $id } = {
            'artist' => $artist,
            'clean_artist' => $clean_artist,
            'tags' => $tags,
            'count' => $count,
        };
    }

    print $FH "DONE!";

    return $audio;
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

sub updateAdditional {
    my ($d, $user_id, $add) = @_;

    my $sql = "select `additional` from `Sync` where user_id = ?";
    my $sth = $d->prepare($sql);
    $sth->execute( $user_id );
    my ($json) = $sth->fetchrow_array();

    $json = $json ? decode_json($json) : { };

    foreach my $k (keys %$add) {
        $json->{$k} = $add->{$k};
    }

    $sql = "update `Sync` set additional = ? where user_id = ?";
    $sth = $d->prepare($sql);

    $sth->execute(
        encode_json($json),
        $user_id, 
    ); 
}

sub saveTags {
    my ($d, $user_id, $list, $FH) = @_;

    print $FH "\n\tUID $user_id: SAVE TAGS... ";

    my $stat      = {};
    my $art_stat  = {};
    my $val_max   = 0;
    my $count_max = 0;

    foreach my $id (keys %$list) {
        my $tags  = $list->{$id}{'tags'};
        my $count = $list->{$id}{'count'};

        if ($tags) {
            my $tags_json = decode_json($tags);

            foreach my $tag (keys %$tags_json) {
                $stat->{'count'}{$tag} += $count;
                $stat->{'sum'}{$tag} += $tags_json->{$tag} * $count;

                if ($stat->{'sum'}{$tag} > $val_max) {
                    $val_max = $stat->{'sum'}{$tag};
                }
            }
        }

        my $cartist = $list->{$id}{'clean_artist'};
        $art_stat->{'count'}{$cartist} += $count; 

        if ($count > $count_max) {
            $count_max = $count;
        }
    }

    foreach my $artist (keys %{ $art_stat->{'count'} }) {
        my $count = $art_stat->{'count'}{$artist};
        my $p = $count * 100 / $count_max;

        my $art_val = 1;
        if ($p > 80) {
            $art_val = 5;
        } elsif ($p > 60 && $p <= 80) {
            $art_val = 4;
        } elsif ($p > 40 && $p <= 60) {
            $art_val = 3;
        } elsif ($p > 20 && $p <= 40) {
            $art_val = 2;
        }
        
        $art_stat->{'norm'}{$artist} = $art_val;
    }

    foreach my $tag (keys %{ $stat->{'sum'} }) {
        my $val = $stat->{'sum'}{$tag};
        my $p = $val * 100 / $val_max;
        
        my $tag_val = 1;
        if ($p > 80) {
            $tag_val = 5;
        } elsif ($p > 60 && $p <= 80) {
            $tag_val = 4;
        } elsif ($p > 40 && $p <= 60) {
            $tag_val = 3;
        } elsif ($p > 20 && $p <= 40) {
            $tag_val = 2;
        }

        $stat->{'norm'}{$tag} = $tag_val;
    }

    my $tags_count_str = encode_json( $stat->{'count'} || {} );
    my $tags_sum_str   = encode_json( $stat->{'sum'} || {} );
    my $tags_norm_str  = encode_json( $stat->{'norm'} || {} );
    my $art_norm_str   = encode_json( $art_stat->{'count'} || {} );

    my $sql = "update `User` set tags = ?, tags_full = ?, tags_normal = ?, artists_normal = ? where id = ?";
    my $sth = $d->prepare($sql);

    $sth->execute(
        $tags_count_str,
        $tags_sum_str,
        $tags_norm_str,
        $art_norm_str,
        $user_id
    ); 
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

sub sync {
    my ($d, $config, $FH, $to_sync) = @_;

    my $sync_id = $to_sync->{'id'};
    my $user_id = $to_sync->{'user_id'};

    # Get Network Audio List
    updateSyncStatus($d, $user_id, 2); # sync audio list
    my $audio_list = getAudioList($user_id, $to_sync->{'access_token'}, $config, $FH);

    if (!$audio_list) {
        updateSyncStatus($d, $user_id, -1); # sync error 
        print $FH "\nSYNC $sync_id: ERROR (cannot get audio list)";
        die;
    }

    # Sync DB
    updateSyncStatus($d, $user_id, 3); # sync audio & artists 
    syncAudioDb($d, $to_sync->{'user_id'}, $audio_list, $FH);

    my $actual_audio_list = getUserAudio($d, $user_id);

    syncArtistDb($d, $user_id, $actual_audio_list, $FH);

    my $actual_artist_list = getUserAudioArtist($d, $user_id, $FH);

    # Sync tags 
    updateSyncStatus($d, $user_id, 4); # sync tags 
    analyzeTags($d, $user_id, $config, $actual_artist_list, $FH);

    $actual_artist_list = getUserAudioArtist($d, $user_id, $FH);

    saveTags($d, $user_id, $actual_artist_list, $FH);

    updateSyncStatus($d, $to_sync->{'user_id'}, 1); # sync done 

    return;
}

# MAIN

my $params = getParameters();
$params = $params->{'parameters'}; 

my $config = getConfig();
$config = $config->{'parameters'}; 

my $pf = '/var/run/emsync/run.pid';
my $wd = '/var/run/emsync';
my $ld = '/tmp/emsync.log';
my $daemon = Proc::Daemon->new(
    pid_file => $pf,
    work_dir => $wd 
);

my $last_check_time = 0;

my $pid = $daemon->Status($pf);
my $daemonize = 1;

GetOptions(
    'daemon!' => \$daemonize,
    "start" => \&run,
    "status" => \&status,
    "stop" => \&stop
);

sub stop {
    if ($pid) {
        print "Stopping pid $pid...\n";
        if ($daemon->Kill_Daemon($pf)) {
            print "Successfully stopped.\n";
        } else {
            print "Could not find $pid.  Was it running?\n";
        }
    } else {
        print "Not running, nothing to stop.\n";
    }
}

sub status {
    if ($pid) {
        print "Running with pid $pid.\n";
    } else {
        print "Not running.\n";
    }
}

sub run {
    if (!$pid) {
        print "Starting...\n";
        if ($daemonize) {
            $daemon->Init;
        }

        while (42) {
            my $d = connectDb( $params );

            my $sync_list = whatSync($d);
            $d->disconnect();

            open(my $FH, '>>', $ld);

            if ( scalar(@$sync_list) > 0 ) {
                print $FH "\nSYNC: ".scalar(@$sync_list)." user ready to sync";
                my $pm = Parallel::ForkManager->new($MAX_PROCESSES);

                foreach my $s (@$sync_list) {
                    my $sync_id = $s->{'id'};
                    print $FH "\nSYNC $sync_id: START";

                    my $pid = $pm->start and next;

                    my $dc = connectDb( $params );
                    sync($dc, $config, $FH, $s);

                    $dc->disconnect();

                    print $FH "\nSYNC $sync_id: DONE";
                }

                 $pm->finish; 

            } else {
                if (time() > ($last_check_time + 60)) {
                    my $dt = DateTime->now();
                    print $FH "\n".$dt->ymd()." ".$dt->hms()." i'm alive!";
                    $last_check_time = time();
                }
            }

            close $FH;

            sleep(1);
        }

    } else {
        print "Already Running with pid $pid\n";
    }
}


