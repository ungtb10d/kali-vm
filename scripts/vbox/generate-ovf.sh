#!/bin/bash

set -eu

fail() { echo "$@" >&2; exit 1; }
usage() { fail "Usage: $(basename $0) VMDK"; }

get_vmdk_disk_uuid() {

    # Get the UUID of a .vmdk disk
    # (should propose this feature to 'qemu-img info')

    local disk=$1
    local magic=

    magic=$(head -c4 $disk)
    if [ "$magic" != KDMV ]; then
        return
    fi

    dd skip=1 count=2 if=$disk 2>/dev/null \
        | sed -n "s/^ddb\.uuid\.image=//p" | tr -d '"'
}

get_virtual_disk_size() {

    # Get the size of a virtual disk. Tested with: .vmdk, .vdi.

    local disk=$1

    qemu-img info $disk \
        | grep "^virtual size: " \
        | sed -E "s/.* \(([0-9]+) bytes\)$/\1/"
}

# Validate arguments

[ $# -eq 1 ] || usage

disk_path=$1

[ ${disk_path##*.} = vmdk ] || fail "Invalid input file '$disk_path'"

description_template=scripts/templates/vm-description.txt
ovf_template=scripts/templates/vm-definition.ovf

# Prepare all the values

disk_file=$(basename $disk_path)
name=${disk_file%.*}

arch=${name##*-}
[ "$arch" ] || fail "Failed to get arch from image name '$name'"
version=$(echo $name | sed -E 's/^kali-linux-(.+)-.+-.+$/\1/')
[ "$version" ] || fail "Failed to get version from image name '$name'"

disk_size=$(get_virtual_disk_size $disk_path)
disk_uuid=$(get_vmdk_disk_uuid $disk_path)
machine_uuid=$(cat /proc/sys/kernel/random/uuid)

license="GPL v3 ~ https://www.kali.org/docs/policy/kali-linux-open-source-policy/"
product="Kali Linux"
product_url="https://www.kali.org/"
product_version="Rolling ($version)"
vendor="Offensive Security"
vendor_url="https://www.offensive-security.com/"

# For OS IDs and types, refer to:
# https://docs.openlmi.org/en/latest/mof/CIM_SoftwareElement.html
case $arch in
    amd64)
        long_mode=true
        os_id=96
        os_type=Debian_64
        platform=x64
        product_version="$product_version x64"
        ;;
    i386)
        long_mode=false
        os_id=95
        os_type=Debian
        platform=x86
        product_version="$product_version x86"
        ;;
    *)
        echo "Invalid architecture '$arch'" >&2
        exit 1
        ;;
esac

# Create the description

description=$(sed \
    -e "s|%date%|$(date --iso-8601)|g" \
    -e "s|%kbdlayout%|US keyboard layout|g" \
    -e "s|%platform%|$platform|g" \
    -e "s|%version%|$version|g" \
    $description_template)

# Create the .ovf file

output=${disk_path%.*}.ovf

sed \
    -e "s|%Capacity%|$disk_size|g" \
    -e "s|%DiskFile%|$disk_file|g" \
    -e "s|%DiskUUID%|$disk_uuid|g" \
    -e "s|%License%|$license|g" \
    -e "s|%LongMode%|$long_mode|g" \
    -e "s|%MachineName%|$name|g" \
    -e "s|%MachineUUID%|$machine_uuid|g" \
    -e "s|%OSId%|$os_id|g" \
    -e "s|%OSType%|$os_type|g" \
    -e "s|%Product%|$product|g" \
    -e "s|%ProductUrl%|$product_url|g" \
    -e "s|%ProductVersion%|$product_version|g" \
    -e "s|%Vendor%|$vendor|g" \
    -e "s|%VendorUrl%|$vendor_url|g" \
    -e "s|%VirtualSystemId%|$name|g" \
    -e "s|%VirtualSystemIdentifier%|$name|g" \
    $ovf_template > $output

awk -v r="$description" '{ gsub(/%Description%/,r); print }' $output > $output.1
mv $output.1 $output

unmatched_patterns=$(grep -E -n "%[A-Za-z_]+%" $output || :)
if [ "$unmatched_patterns" ]; then
    echo "Some patterns where not replaced in '$output':" >&2
    echo "$unmatched_patterns" >&2
    exit 1
fi
