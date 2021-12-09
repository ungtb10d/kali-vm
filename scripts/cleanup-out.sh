#!/bin/bash

# XXX mostly taken from internal wiki

set -eu

rm -f  $ROOTDIR/etc/ssh/ssh_host_*
rm -fr $ROOTDIR/tmp/*
rm -fr $ROOTDIR/var/tmp/*

#rm -fr $ROOTDIR/var/lib/apt/lists/*
