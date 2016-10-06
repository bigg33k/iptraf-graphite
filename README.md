# iptraf-graphite
[![Build Status](https://travis-ci.org/bigg33k/iptraf-graphite.svg?branch=master)](https://travis-ci.org/bigg33k/iptraf-graphite)

Largley based on http://www.taedium.com/rrd-iptraf/ and http://www.taedium.com/rrd-iptraf/iptraf.txt

I've modified the script to insert the results of the log into Graphite

The basics:

-Set up iptraf

-Run `iptraf -s eth0 -B` (I set it @reboot in Cron for ease)

-Run `iptraf-graphite.pl` in cron at appropriate frequency

I recommend having the logging of iptraf set to 1 minute and running the script minutely.
