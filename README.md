ipset-fw
===============

Blocklist firewall based of ipsets/iptables.
Features fetching of online ip-lists (cidr e.g. from iblocklists).
Optional systemd configuration to run daily and for persistence.

## Setup
```sh
cp ipset-fw.sh /usr/local/bin/ipset-fw
chmod +x /usr/local/sbin/ipset-fw

mkdir /etc/ipset-fw
cp ipset-fw.conf /etc/ipset-fw/

```

## iptables filter rules
### automatic
Set `FORCE=yes` in ipset-fw.conf (default)
### manual
https://serverfault.com/a/907955
```sh
iptables -N ipset-fw
iptables -I INPUT 1 -m set --match-set blacklist src -j DROP
iptables -I INPUT 1 -m set --match-set whitelist src -j RETURN
iptables -I INPUT 1 -j ipset-fw

iptables-save > /etc/iptables/iptables.rules
systemctl enable iptables
```

## ipset persistence
```sh
touch /etc/ipset.conf
systemctl enable ipset
```

## Configure the lists / sources
Lists contain single ip4 address or /netsmask notation for ip ranges (cidr).
```sh
nano /etc/ipset-fw/ipset-fw.config
...
BLACKLISTS=(
   #"file:///etc/ipset-fw/black.list" # optional personal lists
   #"file:///etc/ipset-fw/nolan.list"
   "https://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot...
...
WHITELISTS=(
   #"file:///etc/ipset-fw/white.list" optional whitelist
...
```

## Systemd service and timer
```sh
cp ipset-fw.service /etc/systemd/system/
cp ipset-fw.timer /etc/systemd/system/

systemctl enable ipset-fw.timer
```

## Check for dropped packets
```
iptables -L INPUT -v --line-numbers
```

## Run
```sh
systemctl start ipset-fw

# Check status / log
systemctl status ipset-fw
journalctl -u ipset-fw

# Check ipset and size
ipset -L | grep -C 8 blacklist

# Check set INPUT rules at the top
iptables -L | head
```
