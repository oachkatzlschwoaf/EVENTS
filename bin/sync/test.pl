#!/usr/bin/perl

use strict;
use warnings;

use EV;
use AnyEvent::DBI::MySQL;
use JSON;
use YAML;
use DBI;
use Data::Dumper;

use POSIX ":sys_wait_h";

our $max_pool_size = 100;
our $max_work_time = 60;

our %POOL = ();
my ($t, $t1);

$|++;

$SIG{CHLD} = \&REAPER;
sub REAPER {
    my $pid;

    $pid = waitpid(-1, &WNOHANG);

    delete $POOL{$pid};
    $SIG{CHLD} = \&REAPER;          
}

sub getParameters {
    return YAML::LoadFile("../../app/config/parameters.yml");
}

sub getDb {
    my ($c) = @_;

    return AnyEvent::DBI::MySQL->connect( 'DBI:mysql:'.$c->{'database_name'}.':'.$c->{'database_host'}.':'.$c->{'database_port'}, 
        $c->{'database_user'}, 
        $c->{'database_password'},
        {
            mysql_enable_utf8 => 1,
            mysql_init_command => "set names utf8",
            mysql_auto_reconnect => 1,
            AutoCommit => 1,
        }
    );
}

# MAIN
my $params = getParameters();
$params = $params->{'parameters'}; 

$t = EV::timer 1, 1, sub {
    print "\nStart main loop (".scalar( keys(%POOL) ).")";

    if( !keys %POOL || $max_pool_size < keys %POOL ){
        my $db = getDb($params);

        $db->selectall_arrayref("select `id` from `Sync` where `status` = 0", sub {
            my ($rv, $dbh) = @_;

            if ($rv) {
                foreach my $r ( @$rv ) {
                    my $sync_id = $r->[0];

                    my $pid = fork();
                    if ( $pid == 0 ) {
                        print "\n\tChild $sync_id begin...";
                        `./sync_audio.pl $sync_id`;
                        print "\n\tChild $sync_id done...";

                        exit 0;
                    }

                    print "\nStart new process $sync_id ($pid)";
                    $POOL{$pid} = { queue_id => $sync_id, start_time => time(), mysql => $db };
                }

            } else {
                print "\nNo queue in mysql";
            }

        });
    }
};

EV::loop;
