#!/bin/sh
# Run a Corosync app in a foreground. Assumes there is a config mounted under /tmp
# Evaluate and configure an ip address of the corosync node
IP=`ip addr show | grep -E '^[ ]*inet' | grep -m1 global | awk '{ print $2 }' | sed -e 's/\/.*//'`
cp -f /tmp/corosync.conf /etc/corosync/corosync.conf
sed -i "s/bindnetaddr: 127.0.0.1/bindnetaddr: $IP/g" /etc/corosync/corosync.conf
/usr/sbin/corosync -f
