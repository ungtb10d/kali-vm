#!/bin/sh

set -eu

image=
zip=0

while [ $# -gt 0 ]; do
    case $1 in
        -z) zip=1 ;;
        *) image=$1 ;;
    esac
    shift
done

echo "INFO: Generate $image.vmdk"
rm -fr $image.vmware && mkdir $image.vmware
qemu-img convert -O vmdk -o subformat=twoGbMaxExtentSparse \
    $image.raw $image.vmware/$(basename $image).vmdk

echo "INFO: Generate $image.vmx"
scripts/generate-vmx.sh $image.vmware/$(basename $image).vmdk

cd $(dirname $image)
image=$(basename $image)

if [ $zip -eq 1 ]; then
    echo "INFO: Compress to $image.7z"
    7z a -sdel -mx=9 $image.7z $image.vmware
fi
