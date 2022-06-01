#!/bin/sh

set -eu

export DEBIAN_FRONTEND=noninteractive

apt-get autoremove --purge -y
apt-get clean

rc_packages=$(dpkg --list | grep "^rc" | cut -d " " -f 3)
for pkg in $rc_packages; do
    dpkg --purge $pkg
done
