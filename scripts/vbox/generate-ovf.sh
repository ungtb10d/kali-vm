#!/bin/sh

# XXX In long description, shouldn't hardcode "US keyboard layout"

set -eu

fail() { echo "$@" >&2; exit 1; }
usage() { fail "Usage: $(basename $0) VMDK"; }

# Validate arguments

[ $# -eq 1 ] || usage

vmdk_path=$1

[ ${vmdk_path##*.} = vmdk ] || fail "Invalid input file '$vmdk_path'"

description_template_path=scripts/templates/vm-description.txt
ovf_template_path=script/templates/vbox.ovf


# Prepare all the values

vmdk=$(basename $vmdk_path)
name=${vmdk%.*}
arch=${name##*-}
version=$(echo $name | cut -d- -f3)

size=$(qemu-img info $vmdk_path | sed -E -n "s/^virtual size: .* GiB \(([0-9]+) bytes\)/\1/p")

disk_uuid=$(cat /proc/sys/kernel/random/uuid)
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

# Override values for Kali 2021.3 amd64
#size=85899345920
#vmdk=Kali-Linux-2021.3-vbox-amd64-disk001.vmdk
#name=Kali-Linux-2021.3-vbox-amd64
#disk_uuid=700dc347-3774-4123-be9d-47c585f61781
#machine_uuid=cf14878a-f9a0-47ce-8c7b-c0b95e2c2069

# Override values for Kali 2021.3 i386
#size=85899345920
#vmdk=Kali-Linux-2021.3-vbox-i386-disk001.vmdk
#name=Kali-Linux-2021.3-vbox-i386
#disk_uuid=b75fc92d-4a0f-43c8-b3fa-7e44dc561220
#machine_uuid=67890c86-5d34-4d71-b682-fa9e99099f8c


# Create the description

description=$(sed \
	-e "s|%date%|$(date --iso-8601)|g" \
	-e "s|%platform%|$platform|g" \
	-e "s|%version%|$version|g" \
	$description_template_path)

# Create the .ovf file

output=${vmdk_path%.*}.ovf

sed \
	-e "s|%Capacity%|$size|g" \
	-e "s|%DiskFile%|$vmdk|g" \
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
	$ovf_template_path > $output

awk -v r="$description" '{gsub(/%Description%/,r)}1' $output > $output.1
mv $output.1 $output

unmatched_patterns=$(grep -E -n "%[A-Za-z_]+%" $output)
if [ "$unmatched_patterns" ]; then
	echo "Some patterns where not replaced in '$output':" >&2
	echo "$unmatched_patterns" >&2
	exit 1
fi
