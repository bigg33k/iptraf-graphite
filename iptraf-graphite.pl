#!/usr/bin/perl -l

##  parse Iptraf logs and insert metrics into graphite

use strict;
use warnings;

use IO::File;
use IO::Socket::INET;
use Time::Local;
use Net::Statsd;
use Time::HiRes;

my $GRAPHITEHOST="YOUR.GRAPHITE.HOST";
my $GRAPHITEPORT=2003;
$Net::Statsd::HOST = $GRAPHITEHOST;
$Net::Statsd::PORT = 8125;

my $start_time = [ Time::HiRes::gettimeofday ];
my $DEBUG=0;
my $site = "home";
my $timestamp = 0;


my $sock = IO::Socket::INET->new(
        PeerAddr => $GRAPHITEHOST,
        PeerPort => $GRAPHITEPORT,
        Proto    => 'tcp'
);
die "Unable to connect: $!\n" unless ($sock->connected);

my $LASTHOUR=time()-(5000);
print "starting at $LASTHOUR\n" if $DEBUG;

my $fh = IO::File->new('/var/log/iptraf/tcp_udp_services-eth0.log')
    or die "Can't open logfile";

while (<$fh>) {
    if ( m/service monitor started/ ) { _reset( $_ ); }
    next unless ( m/^\*\*\*/ );
    _parse( $_, $fh );
}
Net::Statsd::timing('iptraf.overall', Time::HiRes::tv_interval($start_time) * 1000);
## translate iptraf's time string into unixtime
sub _get_time {

    my $start_get_time = [ Time::HiRes::gettimeofday ];
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

    Net::Statsd::timing('iptraf.get_time', Time::HiRes::tv_interval($start_get_time) * 1000);
    return timelocal( $second, $minute, $hour, $date, $month, $year );
}

## parse the log to the end.  small race condition if we start reading
## log file while iptraf is writing?
sub _parse {

    my $start_parse_time = [ Time::HiRes::gettimeofday ];
    my ($header, $fh) = @_;

    my $logtime;
    my $worktime;

    $logtime = _get_time( ($header =~ m/generated (.*)/)[0] );
    return unless $logtime > $LASTHOUR + 60;
    $timestamp = $logtime;

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
        print ("iptraf.$site.$proto.$port.packets $packs $timestamp\n") if $DEBUG;
        print ("iptraf.$site.$proto.$port.bytes_total $bytes $timestamp\n") if $DEBUG;
        print ("iptraf.$site.$proto.$port.packets_in $pack_in  $timestamp\n") if $DEBUG;
        print ("iptraf.$site.$proto.$port.bytes_in $byte_in $timestamp\n") if $DEBUG;
        print ("iptraf.$site.$proto.$port.packets_out $pack_out  $timestamp\n") if $DEBUG;
        print ("iptraf.$site.$proto.$port.bytes_out $byte_out $timestamp\n") if $DEBUG;
    }

    Net::Statsd::timing('iptraf.parse', Time::HiRes::tv_interval($start_parse_time) * 1000);
}

## iptraf has restarted, put 'U' (unknown) in db.
sub _reset {
    my ($line) = @_;

}


