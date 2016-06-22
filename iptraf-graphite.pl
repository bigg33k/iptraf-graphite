#!/usr/bin/perl -l

##  parse Iptraf logs and insert metrics into graphite

use strict;
use warnings;

use IO::File;
use IO::Socket::INET;
use Time::Local;

my $site = "home";
my $timestamp = 0;

my $GRAPHITEHOST="YOUR.GRAPHITE.HOST";
my $GRAPHITEPORT=2003;

my $sock = IO::Socket::INET->new(
        PeerAddr => $GRAPHITEHOST,
        PeerPort => $GRAPHITEPORT,
        Proto    => 'tcp'
);
die "Unable to connect: $!\n" unless ($sock->connected);

my $LAST = `rrdtool last /home/dave/tcp_services.rrd`;
chomp $LAST;

my $fh = IO::File->new('/var/log/iptraf/tcp_udp_services-eth0.log')
    or die "Can't open logfile";

while (<$fh>) {
    if ( m/service monitor started/ ) { _reset( $_ ); }
    next unless ( m/^\*\*\*/ );
    my $hash = _parse( $_, $fh );
}

## translate iptraf's time string into unixtime
sub _get_time {
    my ($input) = @_;

    my ($day, $month, $date, $hour, $minute, $second, $year) = 
            split( /\s+|:/, $input );

    $month = $month eq 'Jan' ? 0  :
             $month eq 'Feb' ? 1  :
             $month eq 'Mar' ? 2  :
             $month eq 'Apr' ? 3  :
             $month eq 'May' ? 4  :
             $month eq 'Jun' ? 5  :
             $month eq 'Jul' ? 6  :
             $month eq 'Aug' ? 7  :
             $month eq 'Sep' ? 8  :
             $month eq 'Oct' ? 9  :
             $month eq 'Nov' ? 10 :
             $month eq 'Dec' ? 11 : undef;

    die "Bad date $input" unless defined ( $month );

    return timelocal( $second, $minute, $hour, $date, $month, $year );
}

## parse the log to the end.  small race condition if we start reading
## log file while iptraf is writing?
sub _parse {
    my ($header, $fh) = @_;

    my %hash;
    $hash{_time} = _get_time( ($header =~ m/generated (.*)/)[0] );

    return unless $hash{_time} > $LAST + 60;
    $timestamp= $hash{_time};

    while (<$fh>) {
        last if ( m/^Running/ );
        next if ( m/^\s*$/ );

        ## read data for tcp packets
        my ($proto) = $_ =~ m/^([^\/]+)/;
        my ($port, $packs, $bytes, $pack_in, $byte_in, $pack_out, $byte_out) =
            $_ =~ m/(\d+)/g;
	$sock->send ("iptraf.$site.$proto.$port.packets $packs $timestamp\n");
	$sock->send ("iptraf.$site.$proto.$port.bytes_total $bytes $timestamp\n"); 
	$sock->send ("iptraf.$site.$proto.$port.packets_in $pack_in  $timestamp\n"); 
	$sock->send ("iptraf.$site.$proto.$port.bytes_in $byte_in $timestamp\n"); 
	$sock->send ("iptraf.$site.$proto.$port.packets_out $pack_out  $timestamp\n"); 
	$sock->send ("iptraf.$site.$proto.$port.bytes_out $byte_out $timestamp\n");	
        $hash{$port} = [$byte_in, $byte_out];
    }

    return \%hash;
}

## iptraf has restarted, put 'U' (unknown) in db.
sub _reset {
    my ($line) = @_;

    my %hash;
    $hash{_time} = _get_time( (split( /;/, $line))[0] );
}


