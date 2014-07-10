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
        $c->{'database_password'},
        { 'RaiseError' => 1, 'AutoCommit' => 0 }
    );
}

sub whatSync {
    my ($d) = @_;

    my $sql = "select `id`, `user_id`, `network`, `network_id`, `auth_info`, `status`, `last_sync` from `Sync` where status = 0 for update";
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
    my @childs;

    my $d = connectDb( $params );
    $d->do("SET NAMES 'utf8'");
    $d->{'mysql_enable_utf8'} = 1;

    eval {
        my $sync_list = whatSync($d);

        if ( scalar(@$sync_list) > 0 ) {
            print "\nSYNC: ".scalar(@$sync_list)." user ready to sync";

            foreach my $s (@$sync_list) {
                my $id = $s->{'id'};
                print "\n\tSYNC: $id sync...";

                my $pid = fork();
                if ($pid) {
                    # parent
                    #print "pid is $pid, parent $$\n";
                    push(@childs, $pid);
                } elsif ($pid == 0) {
                    # child
                    my $x = int( rand(10) );

                    sub1($x);
                    exit 0;
                } else {
                    die "couldnt fork: $!\n";
                }
            }

        } else {
            print "\nnothing to do...";
        }
    };

    if ($@) {
        print "\nERROR: $@";
        $d->rollback();
    }

    $d->disconnect();

    foreach (@childs) {
        my $tmp = waitpid($_, 0);
        print "done with pid $tmp\n";
    }

    sleep(2);
}

sub sub1 {
    my $num = shift;
    print "started child process for $num\n";
    sleep $num;
    print "done with child process for $num\n";
    return $num;
}
