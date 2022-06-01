#!/bin/bash

set -eu

WELL_KNOWN_CACHING_PROXIES="\
3142 apt-cacher-ng
8000 squid-deb-proxy
9999 approx"

SUPPORTED_ARCHITECTURES="amd64 i386"
SUPPORTED_BRANCHES="kali-dev kali-last-snapshot kali-rolling"
SUPPORTED_DESKTOPS="e17 gnome headless i3 kde lxde mate xfce"
SUPPORTED_TOOLSETS="default everything large none"

SUPPORTED_FORMATS="ova ovf raw qemu rootfs virtualbox vmware"
SUPPORTED_VARIANTS="generic qemu rootfs virtualbox vmware"
SUGGESTED_TYPES="generic-ova generic-ovf generic-raw qemu rootfs virtualbox vmware"

DEFAULT_ARCH=amd64
DEFAULT_BRANCH=kali-rolling
DEFAULT_DESKTOP=xfce
DEFAULT_LOCALE=en_US.UTF-8
DEFAULT_MIRROR=http://http.kali.org/kali
DEFAULT_TIMEZONE=US/Eastern
DEFAULT_TOOLSET=default
DEFAULT_USERPASS=kali:kali

ARCH=
BRANCH=
DESKTOP=
KEEP=false
LOCALE=
MIRROR=
PACKAGES=
PASSWORD=
ROOTFS=
SIZE=80
TIMEZONE=
TOOLSET=
TYPE=generic-raw
USERNAME=
USERPASS=
VERSION=
ZIP=false

default_toolset() { [ ${DESKTOP:-$DEFAULT_DESKTOP} = headless ] && echo none || echo default; }
default_version() { echo ${BRANCH:-$DEFAULT_BRANCH} | sed "s/^kali-//"; }

b() { tput bold; echo -n "$@"; tput sgr0; }
fail() { echo "$@" >&2; exit 1; }

ask_confirmation() {
    local question=${1:-"Do you want to continue?"}
    local default=yes
    local default_verbing=
    local choices=
    local grand_timeout=60
    local timeout=20
    local time_left=
    local answer=
    local ret=

    # If stdin is closed, no need to ask, assume yes
    [ -t 0 ] || return 0

    # Set variables that depend on default
    if [ $default = yes ]; then
        default_verbing=proceeding
        choices="[Y/n]"
    else
        default_verbing=aborting
        choices="[y/N]"
    fi

    # Discard chars pending on stdin
    while read -r -t 0; do read -r; done

    # Ask the question, allow for X timeouts before proceeding anyway
    grand_timeout=$((grand_timeout - timeout))
    for time_left in $(seq $grand_timeout -$timeout 0); do
        ret=0
        read -r -t $timeout -p "$question $choices " answer || ret=$?
        if [ $ret -gt 128 ]; then
            if [ $time_left -gt 0 ]; then
                echo "$time_left seconds left before $default_verbing"
            else
                echo "No answer, assuming $default, $default_verbing"
            fi
            continue
        elif [ $ret -gt 0 ]; then
            exit $ret
        else
            break
        fi
    done

    # Process the answer
    [ "$answer" ] && answer=${answer,,} || answer=$default
    case "$answer" in
        (y|yes) return 0 ;;
        (*)     return 1 ;;
    esac
}

[ $(id -u) -eq 0 ] && fail "No need to be root. Please run as normal user."

USAGE="Usage: $(basename $0) [<option>...]

Build a Kali Linux OS image.

Build options:
  -a ARCH     Build an image for this architecture, default: $(b $DEFAULT_ARCH)
              Supported values: $SUPPORTED_ARCHITECTURES
  -b BRANCH   Kali branch used to build the image, default: $(b $DEFAULT_BRANCH)
              Supported values: $SUPPORTED_BRANCHES
  -k          Keep raw disk image and other intermediary build artifacts
  -m MIRROR   Mirror used to build the image, default: $(b $DEFAULT_MIRROR)
  -r ROOTFS   Rootfs to use to build the image, default: $(b none)
  -s SIZE     Size of the disk image in GB, default: $(b $SIZE)
  -t TYPE     Type of image to build (see below for details), default: $(b $TYPE)
              Supported values: $SUGGESTED_TYPES
  -z          Zip images and metadata files after the build

Customization options:
  -D DESKTOP  Desktop environment installed in the image, default: $(b $DEFAULT_DESKTOP)
              Supported values: $SUPPORTED_DESKTOPS
  -L LOCALE   Set locale, default: $(b $DEFAULT_LOCALE)
  -P PACKAGES Install extra packages (comma/space separated list)
  -S TOOLSET  The selection of tools to include in the image, default: $(b $(default_toolset))
              Supported values: $SUPPORTED_TOOLSETS
  -T TIMEZONE Set timezone, default: $(b $DEFAULT_TIMEZONE)
  -U USERPASS Username and password, separated by a colon, default: $(b $DEFAULT_USERPASS)

The different types of images that can be built:
  generic-ova streamOptimized VMDK disk image, OVF metadata file, packed in a OVA archive
  generic-ovf monolithicSparse VMDK disk image, OVF metadata file
  generic-raw sparse raw disk image
  qemu        QCOW2 disk image
  virtualbox  VDI disk image, .vbox metadata file
  vmware      2GbMaxExtentSparse VMDK disk image, VMX metadata file
  rootfs      A root filesystem (no bootloader/kernel), packed in a .tar.gz archive

Supported environment variables:
  http_proxy  HTTP proxy URL, refer to the README for more details.

Refer to the README for examples.
"

while getopts ":a:b:D:hkL:m:P:r:s:S:t:T:U:v:z" opt; do
    case $opt in
        (a) ARCH=$OPTARG ;;
        (b) BRANCH=$OPTARG ;;
        (D) DESKTOP=$OPTARG ;;
        (h) echo "$USAGE" && exit 0 ;;
        (k) KEEP=true ;;
        (L) LOCALE=$OPTARG ;;
        (m) MIRROR=$OPTARG ;;
        (P) PACKAGES="$PACKAGES $OPTARG" ;;
        (r) ROOTFS=$OPTARG ;;
        (s) SIZE=$OPTARG ;;
        (S) TOOLSET=$OPTARG ;;
        (t) TYPE=$OPTARG ;;
        (T) TIMEZONE=$OPTARG ;;
        (U) USERPASS=$OPTARG ;;
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
# from the rootfs name. Moreover, many options don't apply, as they've been
# set already at the time the rootfs was built.
if [ "$ROOTFS" ]; then
    [ $VARIANT != rootfs ] || fail "Option -r can only be used to build images"
    [ -z "$ARCH"    ] || fail "Option -a can't be used together with option -r"
    [ -z "$BRANCH"  ] || fail "Option -b can't be used together with option -r"
    [ -z "$DESKTOP" ] || fail "Option -D can't be used together with option -r"
    [ -z "$LOCALE"  ] || fail "Option -L can't be used together with option -r"
    [ -z "$MIRROR"  ] || fail "Option -m can't be used together with option -r"
    [ -z "$TIMEZONE" ] || fail "Option -T can't be used together with option -r"
    [ -z "$TOOLSET"  ] || fail "Option -S can't be used together with option -r"
    [ -z "$USERPASS" ] || fail "Option -U can't be used together with option -r"
    [ -z "$VERSION" ] || fail "Option -v can't be used together with option -r"
    ARCH=$(basename $ROOTFS | cut -d. -f1 | rev | cut -d- -f1 | rev)
    VERSION=$(basename $ROOTFS | sed -E "s/^rootfs-(.*)-$ARCH\..*/\1/")
else
    [ "$ARCH"    ] || ARCH=$DEFAULT_ARCH
    [ "$BRANCH"  ] || BRANCH=$DEFAULT_BRANCH
    [ "$DESKTOP" ] || DESKTOP=$DEFAULT_DESKTOP
    [ "$LOCALE"  ] || LOCALE=$DEFAULT_LOCALE
    [ "$MIRROR"  ] || MIRROR=$DEFAULT_MIRROR
    [ "$TIMEZONE" ] || TIMEZONE=$DEFAULT_TIMEZONE
    [ "$TOOLSET"  ] || TOOLSET=$(default_toolset)
    [ "$USERPASS" ] || USERPASS=$DEFAULT_USERPASS
    [ "$VERSION" ] || VERSION=$(default_version)
    # Validate some options
    echo $SUPPORTED_BRANCHES | grep -qw $BRANCH \
        || fail "Unsupported branch '$BRANCH'"
    echo $SUPPORTED_DESKTOPS | grep -qw $DESKTOP \
        || fail "Unsupported desktop '$DESKTOP'"
    echo $SUPPORTED_TOOLSETS | grep -qw $TOOLSET \
        || fail "Unsupported toolset '$TOOLSET'"
    # Unpack USERPASS to USERNAME and PASSWORD
    echo $USERPASS | grep -q ":" \
        || fail "Invalid value for -U, must be of the form '<username>:<password>'"
    USERNAME=$(echo $USERPASS | cut -d: -f1)
    PASSWORD=$(echo $USERPASS | cut -d: -f2-)
fi
unset USERPASS

# Validate architecture
echo $SUPPORTED_ARCHITECTURES | grep -qw $ARCH \
    || fail "Unsupported architecture '$ARCH'"

# Validate size and add the "GB" suffix
[[ $SIZE =~ ^[0-9]+$ ]] && SIZE=${SIZE}GB \
    || fail "Size must be given in GB and must contain only digits"

# Order packages alphabetically, separate each package with ", "
PACKAGES=$(echo $PACKAGES | sed "s/[, ]\+/\n/g" | LC_ALL=C sort -u \
    | awk 'ORS=", "' | sed "s/[, ]*$//")

# Attempt to detect well-known http caching proxies on localhost,
# cf. bash(1) section "REDIRECTION". This is not bullet-proof.
echo "# Proxy configuration:"
if ! [ -v http_proxy ]; then
    while read port proxy; do
        (</dev/tcp/localhost/$port) 2>/dev/null || continue
        echo "Detected caching proxy $(b $proxy) on port $(b $port)."
        export http_proxy="http://10.0.2.2:$port"
        break
    done <<< "$WELL_KNOWN_CACHING_PROXIES"
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
[ "$TOOLSET"  ] && echo "* tool selection: $(b $TOOLSET)"
[ "$PACKAGES" ] && echo "* additional packages: $(b $PACKAGES)"
[ "$LOCALE"   ] && echo "* locale: $(b $LOCALE)"
[ "$TIMEZONE" ] && echo "* timezone: $(b $TIMEZONE)"
[ "$USERNAME" ] && echo "* username: $(b $USERNAME)"

# Ask for confirmation before starting the build
ask_confirmation || fail "Abort."

# Notes regarding the scratch size needed to build a Kali image from scratch
# (ie. in one step, no intermediary rootfs), kali-rolling branch and xfce
# desktop, back in June 2022.
# * standard toolset  : 14G
# * large toolset     : 24G
# * everything toolset: 40G
OPTS="-m 4G --scratchsize=45G"

mkdir -p images

if [ $VARIANT = rootfs ]; then
    echo "Building rootfs from recipe $(b rootfs.yaml) ..."
    ROOTFS=images/rootfs-$VERSION-$ARCH.tar.gz
    debos $OPTS \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t locale:$LOCALE \
        -t mirror:$MIRROR \
        -t packages:"$PACKAGES" \
        -t password:"$PASSWORD" \
        -t rootfs:$ROOTFS \
        -t timezone:$TIMEZONE \
        -t toolset:$TOOLSET \
        -t username:$USERNAME \
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
        -t keep:$KEEP \
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
        -t keep:$KEEP \
        -t locale:$LOCALE \
        -t mirror:$MIRROR \
        -t packages:"$PACKAGES" \
        -t password:"$PASSWORD" \
        -t size:$SIZE \
        -t timezone:$TIMEZONE \
        -t toolset:$TOOLSET \
        -t username:$USERNAME \
        -t variant:$VARIANT \
        -t zip:$ZIP \
        full.yaml
fi
