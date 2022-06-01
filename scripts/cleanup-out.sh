#!/bin/sh

set -eu

if [ -z "$ROOTDIR" ]; then
    echo "ERROR: ROOTDIR is empty"
    exit 1
fi

rm -f  $ROOTDIR/etc/ssh/ssh_host_*
rm -fr $ROOTDIR/tmp/*
rm -f  $ROOTDIR/var/log/bootstrap.log
rm -fr $ROOTDIR/var/tmp/*

# Taken from kali-docker, however not sure it's suitable here,
# and we already run 'apt-get clean' anyway, so just don't.
#rm -f  $ROOTDIR/var/cache/ldconfig/aux-cache
#rm -rf $ROOTDIR/var/lib/apt/lists/*
#mkdir  $ROOTDIR/var/lib/apt/lists/partial
#find   $ROOTDIR/var/log -depth -type f -print0 | xargs -0 truncate -s 0

if [ -d $ROOTDIR/script ]; then
    rmdir $ROOTDIR/script
fi
