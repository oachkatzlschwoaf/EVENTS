#!/usr/bin/perl

use utf8;

use strict;
use warnings;

$|++;

use DateTime;
use Encode;
use Data::Dumper;
use List::Util qw( min max );
use JSON;
use YAML;
use DBI;

binmode STDOUT, ':utf8';

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

sub getInternalInfo {
    my ($d) = @_;

    my $stat = { };

    my $dt = DateTime->now();
    my $current_date = $dt->ymd().' 00:00:00';

    # Total 
    my $sql = "select count(id) from `InternalEvent` where status = 1";
    my $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'total'} = $sth->fetchrow_array() || 0;

    # Wait 
    $sql = "select count(id) from `InternalEvent` where status = 0";
    $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'wait'} = $sth->fetchrow_array() || 0;

    # New
    $sql = "select count(id) from `InternalEvent` where status = 1 and created_at > '$current_date'";
    $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'new'} = $sth->fetchrow_array() || 0;

    return $stat;
}


sub getProviderInfo {
    my ($d) = @_;

    my $stat = { };

    my $dt = DateTime->now();
    my $current_date = $dt->ymd().' 00:00:00';

    # Total 
    my $sql = "select count(id) from `ProviderEvent` where status = 1";
    my $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'total'} = $sth->fetchrow_array() || 0;

    # New
    $sql = "select count(id) from `ProviderEvent` where status = 1 and created_at > '$current_date'";
    $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'new'} = $sth->fetchrow_array() || 0;

    # By Providers
    $sql = "select id from `Provider`";
    $sth = $d->prepare($sql);
    $sth->execute();

    while ( my $pid = $sth->fetchrow_array() ) {
        $sql = "select count(id) from `ProviderEvent` where status = 1 and provider = $pid";
        my $sth2 = $d->prepare($sql);
        $sth2->execute();

        $stat->{'provider'}{$pid}{'total'} = $sth2->fetchrow_array() || 0;

        $sql = "select count(id) from `ProviderEvent` where status = 1 and created_at > '$current_date' and provider = $pid";
        $sth2 = $d->prepare($sql);
        $sth2->execute();
          
        $stat->{'provider'}{$pid}{'new'} = $sth2->fetchrow_array() || 0;
    }

    return $stat;
}

sub getTicketsInfo {
    my ($d) = @_;

    my $stat = { };

    my $dt = DateTime->now();
    my $current_date = $dt->ymd().' 00:00:00';

    # Total 
    my $sql = "select count(id) from `Ticket` where status = 1";
    my $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'total'} = $sth->fetchrow_array() || 0;

    # New
    $sql = "select count(id) from `Ticket` where status = 1 and created_at > '$current_date'";
    $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'new'} = $sth->fetchrow_array() || 0;

    return $stat;
}


sub getUsersInfo {
    my ($d) = @_;

    my $stat = { };

    my $dt = DateTime->now();
    my $current_date = $dt->ymd().' 00:00:00';

    # Total 
    my $sql = "select count(id) from `User`";
    my $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'total'} = $sth->fetchrow_array() || 0;

    # New
    $sql = "select count(id) from `User` where created_at > '$current_date'";
    $sth = $d->prepare($sql);
    $sth->execute();

    $stat->{'new'} = $sth->fetchrow_array() || 0;

    return $stat;
}


# MAIN
print "\nGET GLOBAL STAT";
print "\n************************************";

my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");

my $log = { };
$log->{'internal'} = getInternalInfo($d);

$log->{'provider'} = getProviderInfo($d);

$log->{'tickets'} = getTicketsInfo($d);

$log->{'users'} = getUsersInfo($d);


# Save Report as Admin Action
my $dt = DateTime->now();
my $sql = "insert into `AdminAction` (`type`, `info`, `created_at`) 
    values(?, ?, ?)";

my $sth = $d->prepare($sql);
$sth->execute(
    7, # ACTION: DAILY REPORT 
    JSON::encode_json($log),
    $dt->ymd().' '.$dt->hms()
);

print "\nDONE";

