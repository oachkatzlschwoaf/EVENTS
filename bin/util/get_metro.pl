#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use LWP::Simple;
use HTML::TreeBuilder;

binmode STDOUT, ':utf8';

my $c = get('http://www.metro.ru/stations/codes/');

my $t = HTML::TreeBuilder->new_from_content( $c );
my @table = $t->look_down(class => 'data station-codes');
my $table = $table[0];

my @tds = $table->look_down(_tag => 'td');

my $metro = { };

my $i = 0;
foreach my $td (@tds) {
    my $text = $td->as_text;
    Encode::_utf8_on( $text );

    if ($i == 0) {
        $metro->{ $text } = 1; 
    }

    $i++;
    $i = 0 if ($i == 3);
}

print "array(";
foreach my $m (sort { $a cmp $b } keys $metro) {
    print "\n\t'$m' => '$m',";
}
print "\n)";


