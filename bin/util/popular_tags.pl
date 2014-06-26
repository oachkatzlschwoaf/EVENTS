#!/usr/bin/perl

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

sub getIndexTags {
    my ($d) = @_;

    my $sql = "select 
        `internal_id`, 
        `tags_names` 
    from `ActualInternalIndex`";

    my $sth = $d->prepare($sql);
    $sth->execute();

    my $stat = { };

    while ( my ($internal_id, $tags_names) = $sth->fetchrow_array() ) {
        my @tags = split(',', $tags_names);

        foreach my $t (@tags) {
            $stat->{ $t }++;
        }
    }

    return $stat;
}

# MAIN
my $config = getParameters();
my $params = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");
$d->{'mysql_enable_utf8'} = 1;

my $tags_hash = getTags($d);
my $stat = getIndexTags($d);

my @arr;
my $i = 0;

foreach my $t (sort { $stat->{$b} <=> $stat->{$a} } keys %$stat) {
    my $v = $stat->{$t};
    
    push(@arr, $t);

    last if ($i > 30);
    $i++;
}

print "array(";
foreach my $t (@arr) {
    print "'$t', ";
}
print ")";

