#!/usr/bin/perl

use strict;
use warnings;

use EV;
use AnyEvent::DBI::MySQL;
use JSON;
use YAML;
use DBI;
use Data::Dumper;

our $max_pool_size = 100;
our $max_work_time = 60;

our %POOL = ();
my ($t, $t1);

$|++;

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

=pod
$t1 = EV::timer 60, 60, sub {
    warn "Check stale worker";
    my $for_check = [grep {$_->{start_time} + $max_work_time < time()} keys %POOL];
    my $ps_param = join ",", $for_check;
    my $ps_list = {};Делаем вызов ps

    foreach( $for_check ){
        unless( $ps_list->{$_} ){
        warn "Stale pid found";
        my $db = getDb();

        ->do("UPDATE `status` = 0 WHERE `id` = ? and `status` = 1", sub {
        my ($rv, $dbh) = @_;
        if( $rv ne '0E0' ){
        delete $POOL{$_};
        }
        else {
        warn "Update fail!";
        }
        });
        }
        warn "Slow worker! QID: ".$POOL{$_}->{queue_id};
    }
};
=cut

$t = EV::timer 1, 1, sub {
    print "\nStart main loop";

    if( !keys %POOL || $max_pool_size < keys %POOL ){
        my $db = getDb($params);

        $db->selectall_arrayref("select `id` from `Sync` where `status` = 0", sub {
            my ($ary_ref) = @_;
            print "\nhi!";

        });
    }
};

EV::loop;
