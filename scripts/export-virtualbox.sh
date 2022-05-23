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

echo "INFO: Generate $image.vdi"
qemu-img convert -O vdi $image.raw $image.vdi

echo "INFO: Generate $image.vbox"
scripts/generate-vbox.sh $image.vdi

cd $(dirname $image)
image=$(basename $image)

if [ $zip -eq 1 ]; then
    echo "INFO: Compress to $image.7z"
    mkdir $image
    mv $image.vdi $image.vbox $image
    7z a -sdel -mx=9 $image.7z $image
fi
