# iptraf-graphite

Largley based on http://www.taedium.com/rrd-iptraf/ and http://www.taedium.com/rrd-iptraf/iptraf.txt

I've modified the script to insert the results of the log into Graphite

The basics:

  *Set up iptraf

  *run `iptraf -s eth0 -B` (I set it @reboot in Cron for ease)

  *run `iptraf-graphite.pl` in cron at appropriate frequency

I recommend having the logging of iptraf set to 1 minute and running the script minutely.
