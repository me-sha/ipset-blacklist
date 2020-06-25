#!/bin/sh
set -e

cp ipset-fw.sh /usr/local/bin/ipset-fw
chmod +x /usr/local/bin/ipset-fw

mkdir -p /etc/ipset-fw
cp ipset-fw.conf /etc/ipset-fw/
cp nolan.cidr /etc/ipset-fw/

cp ipset-fw.service /etc/systemd/system/
cp ipset-fw.timer /etc/systemd/system/
systemctl enable ipset-fw.timer
