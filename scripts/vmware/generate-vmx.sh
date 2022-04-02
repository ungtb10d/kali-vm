#!/bin/sh

set -eu

fail() { echo "$@" >&2; exit 1; }
usage() { fail "Usage: $(basename $0) VMDK"; }

# Validate arguments

[ $# -eq 1 ] || usage

vmdk_path=$1

[ ${vmdk_path##*.} = vmdk ] || fail "Invalid input file '$vmdk_path'"

description_template=scripts/templates/vm-description.txt
vmx_template=scripts/templates/vmware.vmx


# Prepare all the values

vmdk=$(basename $vmdk_path)
name=${vmdk%.*}
nvram=${name}.nvram
vmxf=${name}.vmxf

arch=${name##*-}
[ "$arch" ] || fail "Failed to get arch from image name '$name'"
version=$(echo $name | sed -E 's/^kali-linux-(.+)-.+-.+$/\1/')
[ "$version" ] || fail "Failed to get version from image name '$name'"

# https://kb.vmware.com/s/article/1010806
vmci_id=$(od -vAn -N4 -tu4 < /dev/urandom)

case $arch in
    amd64)
        platform=x64
        guest_os=debian10-64
        ;;
    arm64)
        platform=arm64
        guest_os=arm-debian11-64
        ;;
    i386)
        platform=x86
        guest_os=debian10
        ;;
    *)
        echo "Invalid architecture '$arch'" >&2
        exit 1
        ;;
esac

# Overrides for Kali 2021.4 amd64

name=Kali-Linux-2021.4-vmware-amd64
nvram=Kali-Linux-2021.4-vmware-amd64.nvram
vmdk=Kali-Linux-2021.4-vmware-amd64.vmdk
vmxf=Kali-Linux-2021.4-vmware-amd64.vmxf
uuid="56 4d af c5 02 43 11 30-39 39 3c 7c a9 c5 0f d0"
vmci_id=1834882282

# Overrides for Kali 2021.4 i386

name=Kali-Linux-2021.4-vmware-i386
nvram=Kali-Linux-2021.4-vmware-i386.nvram
vmdk=Kali-Linux-2021.4-vmware-i386.vmdk
vmxf=Kali-Linux-2021.4-vmware-i386.vmxf
uuid="56 4d ea 6a 11 a2 4c bc-1a f1 13 0d 6e b4 34 17"
vmci_id=1857303575

# Overrides for Kali 2021.4 arm64
name=Kali-Linux-2021.4-vmware-arm64
nvram=Kali-Linux-2021.4-vmware-arm64.nvram
vmdk=Kali-Linux-2021.4-vmware-arm64.vmdk
vmxf=Kali-Linux-2021.4-vmware-arm64.vmxf
# TODO: These are copied from i386; we didn't do an arm64 2021.4 release
uuid="56 4d ea 6a 11 a2 4c bc-1a f1 13 0d 6e b4 34 17"
vmci_id=1857303575



# Create the description

description=$(sed \
    -e "s|%date%|$(date --iso-8601)|g" \
    -e "s|%kbdlayout%|US keyboard layout|g" \
    -e "s|%platform%|$platform|g" \
    -e "s|%version%|$version|g" \
    $description_template)

annotation=$(echo "$description" | awk "{print}" ORS='\\|0D\\|0A')

# Create the .vmx file

output=${vmdk_path%.*}.vmx

sed \
    -e "s|%annotation%|$annotation|g" \
    -e "s|%displayName%|$name|g" \
    -e "s|%extendedConfigFile%|$vmxf|g" \
    -e "s|%fileName%|$vmdk|g" \
    -e "s|%guestOS%|$guest_os|g" \
    -e "s|%nvram%|$nvram|g" \
    -e "s|%vmciId%|$vmci_id|g" \
    $vmx_template > $output

# Tweaks for i386, is it really needed?
if [ $arch = i386 ]; then
    sed -i \
        -e "/^ethernet0\.virtualDev/d" \
        -e "/^vcpu\.hotadd/d" \
        $output
fi

# XXX For now we don't bother with vmxf or nvram
#sed -i "/^extendedConfigFile/d" $output
#sed -i "/^nvram/d" $output

unmatched_patterns=$(grep -E -n "%[A-Za-z_]+%" $output || :)
if [ "$unmatched_patterns" ]; then
    echo "Some patterns where not replaced in '$output':" >&2
    echo "$unmatched_patterns" >&2
    exit 1
fi
