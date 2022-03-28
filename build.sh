#!/bin/bash

set -eu

SUPPORTED_ARCHITECTURES="amd64"
SUPPORTED_BRANCHES="kali-dev kali-last-snapshot kali-rolling"
SUPPORTED_DESKTOPS="gnome i3 kde xfce"
SUPPORTED_TYPES="generic qemu rootfs virtualbox"

WELL_KNOWN_PROXIES="\
3142 apt-cacher-ng
8000 squid-deb-proxy
9999 approx"

ARCH=amd64
BRANCH=kali-rolling
DESKTOP=xfce
MIRROR=http://http.kali.org/kali
SIZE=80GiB
TYPE=generic
VERSION=

fail() { echo "$@" >&2; exit 1; }
b() { tput bold; echo -n "$@"; tput sgr0; }

ask_confirmation() {
    local question=${1:-"Do you want to continue?"}
    local answer=
    read -r -p "$question [Y/n] " answer
    [ "$answer" ] && answer=${answer,,} || answer=y
    case "$answer" in
        (y|yes) return 0 ;;
        (*)     return 1 ;;
    esac
}

[ $(id -u) -eq 0 ] && fail "No need to be root. Please run as normal user."

USAGE="Usage: $(basename $0) [<option>...]

Build a Kali Linux OS image.

Options:
  -a ARCH     Build an image for this architecture, default: $ARCH
  -b BRANCH   Kali branch used to build the image, default: $BRANCH
  -d DESKTOP  Desktop environment installed in the image, default: $DESKTOP
  -m MIRROR   Mirror used to build the image, default: $MIRROR
  -s SIZE     Size of the disk image created, default: $SIZE
  -t TYPE     Type of image to build (see below for details), default: $TYPE
  -v VERSION  Release version of Kali, defaults: ${BRANCH#kali-}

Supported values for some options:
  ARCH        $SUPPORTED_ARCHITECTURES
  BRANCH      $SUPPORTED_BRANCHES
  DESKTOP     $SUPPORTED_DESKTOPS
  TYPE        $SUPPORTED_TYPES

The different types of images that can be built are:
  generic     Build a $(b raw) disk image, install all virtualization support packages.
  qemu        Build a $(b qcow2) image, install virtualization support for QEMU.
  virtualbox  Build a $(b ova) image, install virtualization support for VirtualBox.
  rootfs      Build a rootfs (no bootloader/kernel), pack it in a $(b .tar.gz) archive.

Supported environment variables:
  http_proxy  HTTP proxy URL, refer to the README for more details.
"

while getopts ':a:b:d:hm:s:t:v:' opt; do
    case $opt in
        (a) ARCH=$OPTARG ;;
        (b) BRANCH=$OPTARG ;;
        (d) DESKTOP=$OPTARG ;;
        (h) echo "$USAGE" && exit 0 ;;
        (m) MIRROR=$OPTARG ;;
        (s) SIZE=$OPTARG ;;
        (t) TYPE=$OPTARG ;;
        (v) VERSION=$OPTARG ;;
        (*) fail "$USAGE" ;;
    esac
done
shift $((OPTIND - 1))

echo $SUPPORTED_ARCHITECTURES | grep -qw $ARCH \
    || fail "Unsupported architecture '$ARCH'"
echo $SUPPORTED_BRANCHES | grep -qw $BRANCH \
    || fail "Unsupported branch '$BRANCH'"
echo $SUPPORTED_DESKTOPS | grep -qw $DESKTOP \
    || fail "Unsupported desktop '$DESKTOP'"
echo $SUPPORTED_TYPES | grep -qw $TYPE \
    || fail "Unsupported type '$TYPE'"

[ "$VERSION" ] || VERSION=${BRANCH#kali-}

# Print a summary of the build options
if [ $TYPE = rootfs ]; then
    echo "Build a Kali $(b $TYPE) for the $(b $ARCH) architecture."
else
    echo "Build a Kali $(b $TYPE) image for the $(b $ARCH) architecture. Disk size: $(b $SIZE)."
fi
echo "Use the $(b $BRANCH) branch, install the $(b $DESKTOP) desktop environment."
echo "Build the image using the mirror $(b $MIRROR)."

# Attempt to detect well-known http caching proxies on localhost,
# cf. bash(1) section "REDIRECTION". This is not bullet-proof.
if ! [ -v http_proxy ]; then
    while read port proxy; do
        (</dev/tcp/localhost/$port) 2>/dev/null || continue
        echo "Detected caching proxy $(b $proxy) on port $(b $port)."
        export http_proxy="http://10.0.2.2:$port"
        break
    done <<< "$WELL_KNOWN_PROXIES"
fi
if [ "${http_proxy:-}" ]; then
    echo "Using a proxy via env variable: $(b http_proxy=$http_proxy)."
else
    echo "No http proxy configured, all packages will be downloaded from Internet."
fi

# Ask for confirmation before starting the build
ask_confirmation || fail "Abort."

# XXX Size required shouldn't change, but user should be allowed to decide
# whether they want to use RAM or DISK . Default should be disk, while RAM
# shouldn't be allowed if not enough free RAM.

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
