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

use Email::Sender;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP ();
use Email::Simple ();
use Email::Simple::Creator ();

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

sub getEmails {
    my ($d) = @_;

    my $sql = "select `id`, `email` from `User` where subscribe = 1 and email is not null";
    my $sth = $d->prepare($sql);
    $sth->execute();

    my $ret = { };
    while ( my ($id, $email) = $sth->fetchrow_array() ) {
        $ret->{$id} = $email; 
    }

    return $ret;
}

sub getSubscribe {
    my ($uid, $params) = @_;

    my $api_url = $params->{'api_url'};

    my $url = $api_url."/user/".$uid."/subscribe";

    my $ua = LWP::UserAgent->new(); 
    my $response = $ua->get( $url );

    if ($response->code ne '200') {
        return;
    }
    
    return $response->content;
}

sub getTitle {
    my ($uid, $params) = @_;

    my $api_url = $params->{'api_url'};

    my $url = $api_url."/user/".$uid."/subscribe/title";

    my $ua = LWP::UserAgent->new(); 
    my $response = $ua->get( $url );

    if ($response->code ne '200') {
        return;
    }

    my $result = JSON->new->utf8(0)->decode($response->decoded_content); 

    return join(', ', @$result);
}

sub sendEmail {
    my ($email, $content, $title, $p) = @_;


    my $transport = Email::Sender::Transport::SMTP->new({
        host => $p->{'smtpserver'},
        port => $p->{'smtpport'},
        sasl_username => $p->{'smtpuser'},
        sasl_password => $p->{'smtppassword'},
    });

    my $from = 'Афиша Eventmate <events@eventmate.me>';

    Encode::_utf8_on($from);
    Encode::_utf8_on($title);
    Encode::_utf8_on($content);

    my $mail = Email::Simple->create(
        header => [
            To      => $email,
            From    => $from,
            Subject => $title,
        ],
        body => $content,
    );

    $mail->header_set( 'Content-Type' => 'text/html; charset=utf-8;' );

    my $res = sendmail($mail, { transport => $transport });

    print " OK!";
}

# MAIN
my $params = getParameters();
$params = $params->{'parameters'}; 

my $config = getConfig();
$config = $config->{'parameters'}; 

my $d = connectDb( $params );
$d->do("SET NAMES 'utf8'");
$d->{'mysql_enable_utf8'} = 1;

# Get emails to subscribe
my $users_list = getEmails($d);

foreach my $uid (keys %$users_list) {
    print "\nUID $uid";

    my $subscribe = getSubscribe($uid, $config);
    if ($subscribe) {
        my $title = getTitle($uid, $config);

        if ($title) {
            sendEmail($users_list->{$uid}, $subscribe, $title, $config);
        }
    } else {
        print " ERROR!";
    }
}

