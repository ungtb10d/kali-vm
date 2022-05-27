#!/bin/bash

set -eu

SUPPORTED_ARCHITECTURES="amd64"
SUPPORTED_BRANCHES="kali-dev kali-last-snapshot kali-rolling"
SUPPORTED_DESKTOPS="gnome i3 kde xfce"
SUPPORTED_FORMATS="ova ovf raw qemu rootfs virtualbox"
SUPPORTED_VARIANTS="generic qemu rootfs virtualbox"

SUGGESTED_TYPES="generic-ovf generic-raw qemu rootfs virtualbox"

WELL_KNOWN_PROXIES="\
3142 apt-cacher-ng
8000 squid-deb-proxy
9999 approx"

ARCH=
BRANCH=
DESKTOP=
MIRROR=
PACKAGES=
ROOTFS=
SIZE=80
TYPE=generic-raw
VERSION=
ZIP=false

default_arch() { echo amd64; }
default_branch() { echo kali-rolling; }
default_desktop() { echo xfce; }
default_mirror() { echo http://http.kali.org/kali; }
default_version() { echo ${BRANCH:-$(default_branch)} | sed "s/^kali-//"; }

fail() { echo "$@" >&2; exit 1; }
b() { tput bold; echo -n "$@"; tput sgr0; }

ask_confirmation() {
    local question=${1:-"Do you want to continue?"}
    local answer=
    local choices=
    local default=yes
    local timeout=10
    local ret=0

    # Capitalize the default choice
    [ $default = yes ] && choices="[Y/n]" || choices="[y/N]"

    # Discard chars pending on stdin
    while read -r -t 0; do read -n 256 -r -s; done

    # Ask the question
    read -r -t $timeout -p "$question $choices " answer || ret=$?
    if [ $ret -gt 128 ]; then
        echo "No answer, assuming $default."
        answer=$default
        ret=0
    fi
    [ $ret -eq 0 ] || exit $ret
    [ "$answer" ] && answer=${answer,,} || answer=$default
    case "$answer" in
        (y|yes) return 0 ;;
        (*)     return 1 ;;
    esac
}

[ $(id -u) -eq 0 ] && fail "No need to be root. Please run as normal user."

USAGE="Usage: $(basename $0) [<option>...]

Build a Kali Linux OS image.

Options:
  -a ARCH     Build an image for this architecture, default: $(default_arch)
  -b BRANCH   Kali branch used to build the image, default: $(default_branch)
  -d DESKTOP  Desktop environment installed in the image, default: $(default_desktop)
  -m MIRROR   Mirror used to build the image, default: $(default_mirror)
  -p PACKAGES Install extra packages (comma/space separated list)
  -r ROOTFS   Rootfs to use to build the image, default: none
  -s SIZE     Size of the disk image created in GB, default: $SIZE
  -t TYPE     Type of image to build (see below for details), default: $TYPE
  -v VERSION  Release version of Kali, defaults: $(default_version)
  -z          Zip images and metadata files after the build.

Supported values for some options:
  ARCH        $SUPPORTED_ARCHITECTURES
  BRANCH      $SUPPORTED_BRANCHES
  DESKTOP     $SUPPORTED_DESKTOPS
  TYPE        $SUGGESTED_TYPES

The different types of images that can be built are:
  generic-ovf Build a $(b sparse VMDK) disk image and a $(b OVF) metadata file.
  generic-raw Build a $(b sparse raw) disk image.
  qemu        Build a $(b QCOW2) image.
  virtualbox  Build a $(b VDI) disk image and a $(b .vbox) metadata file.
  rootfs      Build a rootfs (no bootloader/kernel), pack it in a $(b .tar.gz) archive.

Supported environment variables:
  http_proxy  HTTP proxy URL, refer to the README for more details.
"

while getopts ":a:b:d:hm:p:r:s:t:v:z" opt; do
    case $opt in
        (a) ARCH=$OPTARG ;;
        (b) BRANCH=$OPTARG ;;
        (d) DESKTOP=$OPTARG ;;
        (h) echo "$USAGE" && exit 0 ;;
        (m) MIRROR=$OPTARG ;;
        (p) PACKAGES="$PACKAGES $OPTARG" ;;
        (r) ROOTFS=$OPTARG ;;
        (s) SIZE=$OPTARG ;;
        (t) TYPE=$OPTARG ;;
        (v) VERSION=$OPTARG ;;
        (z) ZIP=true ;;
        (*) fail "$USAGE" ;;
    esac
done
shift $((OPTIND - 1))

# The image TYPE bundles two settings: the VARIANT (eg. extra packages to
# install, additional configuration, and so on) and the FORMAT. In its long
# form, the TYPE is just VARIANT-FORMAT. More often than not though, variant
# and format are the same, so for convenience a short form is allowed.
if echo $TYPE | grep -q "-"; then
    VARIANT=$(echo $TYPE | cut -d- -f1)
    FORMAT=$(echo $TYPE | cut -d- -f2)
else
    VARIANT=$TYPE
    FORMAT=$TYPE
fi
echo $SUPPORTED_VARIANTS | grep -qw $VARIANT \
    || fail "Unsupported type '$TYPE'"
echo $SUPPORTED_FORMATS | grep -qw $FORMAT \
    || fail "Unsupported type '$TYPE'"
unset TYPE

# When building an image from an existing rootfs, ARCH and VERSION are picked
# from the rootfs name. Moreover, BRANCH, DESKTOP and MIRROR don't apply.
if [ "$ROOTFS" ]; then
    [ $VARIANT != rootfs ] || fail "Option -r can only be used to build images"
    [ -z "$ARCH"    ] || fail "Option -a can't be used together with option -r"
    [ -z "$BRANCH"  ] || fail "Option -b can't be used together with option -r"
    [ -z "$DESKTOP" ] || fail "Option -d can't be used together with option -r"
    [ -z "$MIRROR"  ] || fail "Option -m can't be used together with option -r"
    [ -z "$VERSION" ] || fail "Option -v can't be used together with option -r"
    ARCH=$(basename $ROOTFS | cut -d. -f1 | rev | cut -d- -f1 | rev)
    VERSION=$(basename $ROOTFS | sed -E "s/^rootfs-(.*)-$ARCH\..*/\1/")
else
    [ "$ARCH"    ] || ARCH=$(default_arch)
    [ "$BRANCH"  ] || BRANCH=$(default_branch)
    [ "$DESKTOP" ] || DESKTOP=$(default_desktop)
    [ "$MIRROR"  ] || MIRROR=$(default_mirror)
    [ "$VERSION" ] || VERSION=$(default_version)
fi

# Order packages alphabetically, separate each package by ', '
PACKAGES=$(echo $PACKAGES | sed "s/[, ]\+/\n/g" | LC_ALL=C sort -u \
    | awk 'ORS=", "' | sed "s/[, ]*$//")

# Validate other options
echo $SUPPORTED_ARCHITECTURES | grep -qw $ARCH \
    || fail "Unsupported architecture '$ARCH'"
if [ "$BRANCH" ]; then
    echo $SUPPORTED_BRANCHES | grep -qw $BRANCH \
        || fail "Unsupported branch '$BRANCH'"
fi
if [ "$DESKTOP" ]; then
    echo $SUPPORTED_DESKTOPS | grep -qw $DESKTOP \
        || fail "Unsupported desktop '$DESKTOP'"
fi

[[ $SIZE =~ ^[0-9]+$ ]] && SIZE=${SIZE}GB \
    || fail "Size must be given in GB and must contain only digits"

# Attempt to detect well-known http caching proxies on localhost,
# cf. bash(1) section "REDIRECTION". This is not bullet-proof.
echo "# Proxy configuration:"
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

# Print a summary of the build options
echo "# Build options:"
if [ $VARIANT = rootfs ]; then
    echo "Build a Kali $(b $VARIANT) for the $(b $ARCH) architecture."
else
    if [ "$ROOTFS" ]; then
        echo "Build a Kali $(b $VARIANT) image based on $(b $ROOTFS)."
    else
        echo "Build a Kali $(b $VARIANT) image for the $(b $ARCH) architecture."
    fi
    echo "Export the image to the $(b $FORMAT) format. Disk size: $(b $SIZE)."
fi
[ "$MIRROR"   ] && echo "* mirror: $(b $MIRROR)"
[ "$BRANCH"   ] && echo "* branch: $(b $BRANCH)"
[ "$DESKTOP"  ] && echo "* desktop environment: $(b $DESKTOP)"
[ "$PACKAGES" ] && echo "* additional packages: $(b $PACKAGES)"

# Ask for confirmation before starting the build
ask_confirmation || fail "Abort."

# XXX Size required shouldn't change, but user should be allowed to decide
# whether they want to use RAM or DISK . Default should be disk, while RAM
# shouldn't be allowed if not enough free RAM.

mkdir -p images

OPTS="-m 4G --scratchsize=16G"

if [ $VARIANT = rootfs ]; then
    echo "Building rootfs from recipe $(b rootfs.yaml) ..."
    ROOTFS=images/rootfs-$VERSION-$ARCH.tar.gz
    debos $OPTS \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t mirror:$MIRROR \
        -t packages:"$PACKAGES" \
        -t rootfs:$ROOTFS \
        rootfs.yaml
    exit 0
fi

IMAGE=images/kali-linux-$VERSION-$VARIANT-$ARCH

if [ "$ROOTFS" ]; then
    echo "Building image from recipe $(b image.yaml) ..."
    debos $OPTS \
        -t arch:$ARCH \
        -t format:$FORMAT \
        -t imagename:$IMAGE \
        -t rootfs:$ROOTFS \
        -t size:$SIZE \
        -t variant:$VARIANT \
        -t zip:$ZIP \
        image.yaml
else
    echo "Building image from recipe $(b full.yaml) ..."
    debos $OPTS \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t format:$FORMAT \
        -t imagename:$IMAGE \
        -t mirror:$MIRROR \
        -t packages:"$PACKAGES" \
        -t size:$SIZE \
        -t variant:$VARIANT \
        -t zip:$ZIP \
        full.yaml
fi
