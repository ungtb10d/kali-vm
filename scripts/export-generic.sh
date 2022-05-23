#!/bin/sh

set -eu

image=
ova=0
zip=0

while [ $# -gt 0 ]; do
    case $1 in
        -z) zip=1 ;;
        *) image=$1 ;;
    esac
    shift
done

echo "INFO: Generate $image.vmdk"
qemu-img convert -O vmdk $image.raw $image.vmdk

echo "INFO: Generate $image.ovf"
scripts/generate-ovf.sh $image.vmdk

echo "INFO: Generate $image.mf"
scripts/generate-mf.sh $image.ovf $image.vmdk

cd $(dirname $image)
image=$(basename $image)

if [ $ova -eq 1 ]; then
    # An OVA is simply a tar archive. The .ovf must come first,
    # then the .mf comes either second or last. For details,
    # refer to the OVF spec: https://www.dmtf.org/dsp/DSP0243.
    echo "INFO: Generate $image.ova"
    tar -cvf $image.ova $image.ovf $image.vmdk $image.mf
fi

if [ $zip -eq 1 ]; then
    echo "INFO: Compress to $image.7z"
    if [ $ova -eq 1 ]; then
        7z a -sdel -mx=9 $image.7z $image.ova
    else
        7z a -sdel -mx=9 $image.7z $image.ovf $image.vmdk $image.mf
    fi
fi
