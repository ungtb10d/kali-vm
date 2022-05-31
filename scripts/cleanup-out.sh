#!/bin/bash

# XXX mostly taken from internal wiki

set -eu

rm -f  $ROOTDIR/etc/ssh/ssh_host_*
rm -f  $ROOTDIR/var/log/bootstrap.log
rm -fr $ROOTDIR/tmp/*
rm -fr $ROOTDIR/var/tmp/*

if [ -d $ROOTDIR/script ]; then
    rmdir $ROOTDIR/script
fi

#rm -fr $ROOTDIR/var/lib/apt/lists/*
