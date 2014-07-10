#!/usr/bin/perl

use strict;
use warnings;

use AnyEvent::HTTP::Server;
use Getopt::Long;
use EV;
use JSON::XS;
use AnyEvent::HTTP;

GetOptions(
	"port=i"   => \(my $port   = 1097),
	"server=s" => \(my $server = "localhost:1099"),
	"help"     =>  \my $help,
);

if ($help) { 
	die("Usage perl $0 --port=<port> --server=<HOST:PORT>\n");	
}

my %headers = (headers => {'content-type' => 'application/json' , connection => 'close'} );
my ($n_req, $n_errors, $t0) = (0, 0, time());

my $s = AnyEvent::HTTP::Server->new(
	host => '0.0.0.0',
    port => $port,
    cb   => sub {
		my $request = shift;
		my @args = split('/',$request->uri); shift @args;
		$n_req ++;

        my $answer = { };

        # Args check
		if(scalar(@args) == 0) { 
            my $answer = { 'error' => 'no args' };
            $request->reply(500, encode_json($answer), %headers);
			return ();
        }

        # Get Server Status
		if ($args[0] eq 'status') { 
            $answer = { requests => $n_req, errors => $n_errors, start => $t0 };
            $request->reply(200, encode_json($answer), %headers);
			return ();
		}

        # Sync
        if ($args[0] =~ /\d+/) {
            my $sync = $args[0];

            warn "Check $sync";
            my $delay = int(rand(10)) + 1;
            sleep($delay);

            $answer = { $sync => $delay };
            $request->reply(200, encode_json($answer), %headers);
            return ();
        }

        $answer = { 'error' => 'unknown sync' };
        $request->reply(500, encode_json($answer), %headers);
        return ();
    }
);

$s->listen;
$s->accept;

my $sig = AE::signal INT => sub {
	warn "Stopping server";
    $s->graceful(sub {
		warn "Server stopped";
        EV::unloop;
     });
};

EV::loop;

warn "exiting";
exit(0);

