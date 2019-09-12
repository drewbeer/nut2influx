#!/usr/bin/perl -w
# built by drew me@drew.beer

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use LWP::UserAgent;
use InfluxDB::LineProtocol qw(data2line);
use Config::Simple;
use Log::Log4perl;


Log::Log4perl->init("$Bin/../conf/log.conf");
my $log = Log::Log4perl->get_logger("nut2influx");

$log->info("starting");

# load the config
my $file = "$Bin/../conf/settings.conf";
my $cfg = new Config::Simple($file);
my $upsConfig = $cfg->get_block('ups');

my $upsName = $upsConfig->{'name'}.'@'.$upsConfig->{'host'};

# loop to keep posting data
while(1) {
  $log->info("fetching latest ups data");
  # get the latest data
  my $nutData = nutData();
  # push it to influx
  my $tags = { location=>$upsConfig->{'location'},model=>$upsConfig->{'model'}};
  loadInflux('ups', $nutData, $tags);
  sleep $upsConfig->{'updateInterval'};
}

# extract the data
sub nutData {
  my $ups = ();
  open(LINE, "upsc $upsName|");
  while (my $line = <LINE>) {
    chomp $line;
    my ($name, $value) = split(/\:/, $line);
    $value = cleanData($value);
    $ups->{$name} = $value;
  }
  close(LINE);
  return($ups);
}

# clean up anything funky
sub cleanData {
  my $input = shift;
  unless (defined $input) {
    return
  }
  $input =~ s/\n//g;
  $input =~ s/\r//g;
  $input =~ s/\s+//g;
  return $input;
}

# convert to influx line and send to post
sub loadInflux {
  my $source = shift;
  my $stats = shift;
  my $tags = shift;
  my $influxConfig = $cfg->get_block('influxDB');
  my $url = "http://$influxConfig->{'host'}:$influxConfig->{'port'}/write?db=$influxConfig->{'db'}";

  my $nodeLine = data2line($source, $stats, $tags);
  $log->debug("pushing $nodeLine to $url");
  postPayload($url,$nodeLine);
}

# post data to urls
sub postPayload {
  my $url = shift;
  my $postData = shift;

  my $ua = LWP::UserAgent->new;
  $ua->ssl_opts( verify_hostname => 0 ,SSL_verify_mode => 0x00);
  # set custom HTTP request header fields
  my $req = HTTP::Request->new(POST => $url);
  $req->content($postData);
  my $resp = $ua->request($req);
  my $status = 0;
  if ($resp->is_success) {
    $status = 1;
    my $message = $resp->decoded_content;
  } else {
    $status = 0;
    my $respCode = $resp->code;
    my $respMsg = $resp->message;
  }
  return $status;
}
