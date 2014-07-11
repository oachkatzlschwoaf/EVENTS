#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Parallel::ForkManager;
use Data::Dumper;
use YAML;
use DBI;
use JSON;

$|++;

binmode STDOUT, ':utf8';
my $MAX_PROCESSES = 1000;

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
        $c->{'database_password'},
    );
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

# MAIN
my $params = getParameters();
$params = $params->{'parameters'}; 

my $config = getConfig();
$config = $config->{'parameters'}; 

while (42) {
    my $d = connectDb( $params );
    $d->do("SET NAMES 'utf8'");
    $d->{'mysql_enable_utf8'} = 1;

    my $sync_list = whatSync($d);

    if ( scalar(@$sync_list) > 0 ) {
        print "\nSYNC: ".scalar(@$sync_list)." user ready to sync";
        my $pm = Parallel::ForkManager->new($MAX_PROCESSES);

        foreach my $s (@$sync_list) {
        print "\nSYNC $sync_id: START";
        my $user_id = $to_sync->{'user_id'};

            my $id = $s->{'id'};
            print "\n\tSYNC: $id sync...";
            my $pid = $pm->start and next;

            my $x = int( rand(10) );
            sub1($x);
        }

    } else {
        print "\nnothing to do...";
    }

    $d->disconnect();

    sleep(2);
}

sub sub1 {
    my $num = shift;
    print "\n\tstarted child process for $num\n";
    sleep $num;
    print "\n\tdone with child process for $num\n";
    return $num;
}
