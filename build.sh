#!/bin/bash

set -eu

SUPPORTED_ARCHITECTURES="amd64 arm64"
SUPPORTED_BRANCHES="kali-dev kali-last-snapshot kali-rolling"
SUPPORTED_DESKTOPS="gnome i3 kde xfce"
SUPPORTED_TYPES="generic qemu rootfs virtualbox vmware"
DEFAULT_HTTP_PROXY=http://10.0.2.2:3142

ARCH=amd64
BRANCH=kali-last-snapshot
DESKTOP=xfce
MIRROR=http://http.kali.org/kali
SIZE=80GiB
TYPE=generic
VERSION=localbuild

fail() { echo "$@" >&2; exit 1; }
b() { tput bold; echo -n "$@"; tput sgr0; }

[ $(id -u) -eq 0 ] && fail "No need to be root. Please run as normal user."

USAGE="Usage: $(basename $0) [-a ARCH] [-b BRANCH] [-d DESKTOP] [-m MIRROR] [-s SIZE] [-t TYPE] [-v VERSION]

Build a Kali Linux OS image.
By default, build a $(b $ARCH $TYPE) image of size $(b $SIZE),
use the branch $(b $BRANCH) and the mirror $(b $MIRROR).
Install the $(b $DESKTOP) desktop environment.

Supported values for options:
* architectures: $SUPPORTED_ARCHITECTURES
* branches ... : $SUPPORTED_BRANCHES
* desktops ... : $SUPPORTED_DESKTOPS
* types ...... : $SUPPORTED_TYPES
"

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

# XXX Size required shouldn't change, but user should be allowed to decide
# whether they want to use RAM or DISK . Default should be disk, while RAM
# should't be allowed if not enough free RAM.

#OPTS="-m 8G"
OPTS="--scratchsize=14G"
ROOTFS=rootfs-$ARCH
IMAGE=kali-linux-$VERSION-$TYPE-$ARCH

if [ $TYPE = rootfs ]; then
    debos $OPTS \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t mirror:$MIRROR \
        -t rootfs:$ROOTFS \
        rootfs.yaml
elif [ -e $ROOTFS.tar.gz ]; then
    echo "Re-using the existing rootfs $(b $ROOTFS.tar.gz)."
    read -p "Ok? "
    debos $OPTS \
        -t arch:$ARCH \
        -t imagename:$IMAGE \
        -t rootfs:$ROOTFS \
        -t size:$SIZE \
        -t type:$TYPE \
        image.yaml
else
    debos $OPTS \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t imagename:$IMAGE \
        -t mirror:$MIRROR \
        -t size:$SIZE \
        -t type:$TYPE \
        full.yaml
fi
