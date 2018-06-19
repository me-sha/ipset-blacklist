ipset-fw
===============

Bash script fetch online ip-lists for blacklisting/whitelisting with ipsets/iptables.
Optional systemd configuration to run daily and for persistence.

## setup
```sh
cp ipset-fw.sh /usr/local/sbin/ipset-fw
chmod +x /usr/local/sbin/ipset-fw

mkdir /etc/ipset-fw
cp ipset-fw.conf /etc/ipset-fw/

```

### ipset persistence
```sh
touch /etc/ipset.conf
systemctl enable ipset
```

### iptables filter rules
```sh
iptables -I INPUT 1 -m set --match-set blacklist src -j DROP
iptables -I INPUT 1 -m set --match-set whitelist src -j ACCEPT

iptables-save > /etc/iptables/iptables.rules
systemctl enable iptables
```

## Configure the lists / sources
Lists contain single ip4 address or /netsmask notation for ip ranges (cidr).
```sh
nano /etc/ipset-fw/ipset-fw.config
...
BLACKLISTS=(
   #"file:///etc/ipset-fw/black.list" # optional personal lists
   #"file:///etc/ipset-fw/nolan.list"
   #"http://list.iblocklist.com/?list=<i-blocklist-id>&fileformat=cidr&archiveformat=&username=<user>&pin=<pin>" # i-blocklist personal list

   "https://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot...
...
WHITELISTS=(
   #"file:///etc/ipset-fw/white.list" optional whitelist
...
```

### Systemd service and timer
```sh
cp ipset-fw.service /etc/systemd/system/
cp ipset-fw.timer /etc/systemd/system/

systemctl enable ipset-fw.timer
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

## Check for dropped packets
```sh
iptables -L INPUT -v --line-numbers
```
