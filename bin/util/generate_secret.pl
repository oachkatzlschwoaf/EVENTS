#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use DateTime;
use Encode;
use Data::Dumper;
use YAML;
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);

$|++;
binmode STDOUT, ':utf8';

sub getParameters{
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

sub getTickets {
    my ($d) = @_;

    my $stat = { };

    my $dt = DateTime->now();
    my $current_date = $dt->ymd().' 00:00:00';

    # Total 
    my $sql = "select `id`, `provider_event` from `Ticket`";
    my $sth = $d->prepare($sql);
    $sth->execute();

    while ( my ($tid, $pid) = $sth->fetchrow_array() ) {

        my $hash_str = "$tid-$pid-".rand(1000);
        my $hash = md5_hex($hash_str);

        print "\n$tid = $hash";

        $sql = "update `Ticket` set `secret` = '$hash' where `id` = $tid";
        my $sth2 = $d->prepare($sql);
        $sth2->execute();
    }
}


# MAIN
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

my $tickets = getTickets($d);
