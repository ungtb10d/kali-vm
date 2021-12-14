#!/bin/bash

set -e
set -u

SUPPORTED_ARCHITECTURES="amd64 arm64"
SUPPORTED_BRANCHES="kali-dev kali-last-snapshot kali-rolling"
SUPPORTED_DESKTOPS="gnome i3 kde xfce"
SUPPORTED_TYPES="qemu virtualbox vmware"
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
Defaults to a $TYPE image of size $SIZE.

* supported architectures: $SUPPORTED_ARCHITECTURES
* supported branches ... : $SUPPORTED_BRANCHES
* supported desktops ... : $SUPPORTED_DESKTOPS
* supported types ...... : $SUPPORTED_TYPES
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

echo "Build a Kali $(b $TYPE) image for the $(b $ARCH) architecture. Disk size: $(b $SIZE)."
echo "Use the $(b $BRANCH) branch, install the $(b $DESKTOP) desktop environment."
echo "Build image using the mirror $(b $MIRROR)."
read -p "Ok? "

if ! [ -v http_proxy ]; then
    echo "The http_proxy environment variable is not set."
    echo "Using this proxy then: $(b $DEFAULT_HTTP_PROXY)."
    read -p "Ok? "
    export http_proxy=$DEFAULT_HTTP_PROXY
fi

#MEM="-m 8G"
MEM="--scratchsize=14G"

if false; then
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

if false; then
debos $MEM \
    -t arch:$ARCH \
    -t branch:$BRANCH \
    -t desktop:$DESKTOP \
    -t mirror:$MIRROR \
    ospack.yaml
fi

if true; then
debos $MEM \
    -t arch:$ARCH \
    -t size:$SIZE \
    -t type:$TYPE \
    -t version:$VERSION \
    image.yaml
fi
