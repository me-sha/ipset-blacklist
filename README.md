ipset-fw
===============

Ip black-/white-list(cidr) firewall using ipsets/iptables.
Features fetching of online/local ip-lists (e.g. from iblocklists).
Optional systemd configuration to run daily and for persistence.

## Setup
### prerequisites
ipset iptables curl grep sed
egrep: base-devel package
sort: coreutils package
wc: coreutils package

simply run `# ./install.sh` it does all of the below.
### install bin / conf files
```sh
cp ipset-fw.sh /usr/local/bin/ipset-fw
chmod +x /usr/local/bin/ipset-fw

mkdir /etc/ipset-fw
cp ipset-fw.conf /etc/ipset-fw/

#optional
cp nolan.cidr /etc/ipset-fw/
```
### install systemd service and timer
```sh
cp ipset-fw.service /etc/systemd/system/
cp ipset-fw.timer /etc/systemd/system/

systemctl enable ipset-fw.timer
```

## iptables filter rules
### automatic
Set `FORCE=yes` in ipset-fw.conf (default) for automatic creation of ipsets and iptables-rules.
### manual
https://serverfault.com/a/907955
```sh
iptables -N ipset-fw
iptables -I INPUT 1 -m set --match-set blacklist src -j DROP
iptables -I INPUT 1 -m set --match-set whitelist src -j RETURN
iptables -I INPUT 1 -j ipset-fw
```

## Configure lists / sources
Lists contain single ip4 address or /netsmask notation for ip ranges (cidr).
```sh
nano /etc/ipset-fw/ipset-fw.conf
...
BLACKLISTS=(
    #"file:///etc/ipset-fw/blacklist.cidr" # optional local blacklist (manualy created and maintained)
    #"file:///etc/ipset-fw/nolan.list" # block all lan ipv4 device adresses
    #"http://list.iblocklist.com/?list=<i-blocklist-id>&fileformat=cidr&archiveformat=&username=<user>&pin=<pin>" # i-blocklist user list. requires subscription and to fill in the <values>
    "https://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey  Pot...
...
WHITELISTS=(
    # optional local whitelist (manualy created and maintained)
    "file:///etc/ipset-fw/whitelist.cidr" 
...
```

## Run
```sh
# Via systemd
systemctl start ipset-fw

# Manually
ipset-fw

# Check status / log
systemctl status ipset-fw
journalctl -u ipset-fw

# Check dropped packets
iptables -L ipset-fw -v --line-numbers

# Check ipset and size
ipset -L | grep -C 8 blacklist

# Check set INPUT rules at the top
iptables -L | head

# Temporarly add ip or network to whitelist
ipset add whitelist 10.0.0.0/8

# Temporarly delete ip or network from black list
ipset del blacklist 10.0.0.0/8

# Temporarly remove all addresse from list
ipset flush blacklist
```

## Persistence
### iptables
```sh
iptables-save > /etc/iptables/iptables.rules
systemctl enable iptables
```
### ipsets
```sh
touch /etc/ipset.conf
systemctl enable ipset
```
