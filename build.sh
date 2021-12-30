#!/bin/bash

set -e
set -u

SUPPORTED_ARCHITECTURES="amd64 arm64"
SUPPORTED_BRANCHES="kali-dev kali-last-snapshot kali-rolling"
SUPPORTED_DESKTOPS="gnome i3 kde xfce"
SUPPORTED_TYPES="qemu rootfs virtualbox vmware"
DEFAULT_HTTP_PROXY=http://10.0.2.2:3142

ARCH=amd64
BRANCH=kali-last-snapshot
DESKTOP=xfce
MIRROR=http://http.kali.org/kali
SIZE=80GiB
TYPE=qemu
VERSION=localbuild

USAGE="Usage: $(basename $0) [-a ARCH] [-b BRANCH] [-d DESKTOP] [-m MIRROR] [-s SIZE] [-t TYPE] [-v VERSION]

Build a Kali OS image. The partition table is msdos.
By default, build a $TYPE image of size $SIZE.

Supported values for options:
* architectures: $SUPPORTED_ARCHITECTURES
* branches ... : $SUPPORTED_BRANCHES
* desktops ... : $SUPPORTED_DESKTOPS
* types ...... : $SUPPORTED_TYPES
"

fail() { echo "$@" >&2; exit 1; }
b() { tput bold; echo -n "$@"; tput sgr0; }

while getopts ':a:b:d:hm:s:t:v:' opt; do
    case $opt in
	(a) ARCH=$OPTARG ;;
	(b) BRANCH=$OPTARG ;;
	(d) DESKTOP=$OPTARG ;;
	(h) echo "$USAGE" && exit 0 ;;
	(m) MIRRROR=$OPTARG ;;
	(s) SIZE=$OPTARG ;;
	(t) TYPE=$OPTARG ;;
	(v) VERSION=$OPTARG ;;
	(*) fail "$USAGE" ;;
    esac
done
shift $((OPTIND - 1))

echo $SUPPORTED_ARCHITECTURES | grep -qw $ARCH \
    || fail "Unsupported arch '$ARCH'"
echo $SUPPORTED_BRANCHES | grep -qw $BRANCH \
    || fail "Unsupported branch '$BRANCH'"
echo $SUPPORTED_DESKTOPS | grep -qw $DESKTOP \
    || fail "Unsupported desktop '$DESKTOP'"
echo $SUPPORTED_TYPES | grep -qw $TYPE \
    || fail "Unsupported type '$TYPE'"

if [ $TYPE = rootfs ]; then
    echo "Build a Kali $(b $TYPE) for the $(b $ARCH) architecture."
else
    echo "Build a Kali $(b $TYPE) image for the $(b $ARCH) architecture. Disk size: $(b $SIZE)."
fi
echo "Use the $(b $BRANCH) branch, install the $(b $DESKTOP) desktop environment."
echo "Build the image using the mirror $(b $MIRROR)."
read -p "Ok? "

if ! [ -v http_proxy ]; then
    echo "The http_proxy environment variable is not set."
    echo "Using this proxy then: $(b $DEFAULT_HTTP_PROXY)."
    read -p "Ok? "
    export http_proxy=$DEFAULT_HTTP_PROXY
fi

#MEM="-m 8G"
MEM="--scratchsize=14G"

if [ $TYPE = rootfs ]; then
    debos $MEM \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t mirror:$MIRROR \
        rootfs.yaml
elif [ -e rootfs-$ARCH.tar.gz ]; then
    echo "Re-using the existing rootfs rootfs-$ARCH.tar.gz."
    read -p "Ok? "
    debos $MEM \
        -t arch:$ARCH \
        -t size:$SIZE \
        -t type:$TYPE \
        -t version:$VERSION \
        image.yaml
else
    debos $MEM \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t mirror:$MIRROR \
        -t size:$SIZE \
        -t type:$TYPE \
        -t version:$VERSION \
        full.yaml
fi
