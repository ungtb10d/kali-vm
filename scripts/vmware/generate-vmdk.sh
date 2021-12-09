#!/bin/sh

set -eu

input=$1
outdir=${1%.*}.vmware
image=$(basename ${1%.*})

rm -fr $outdir
mkdir $outdir

qemu-img convert -O vmdk -o subformat=twoGbMaxExtentSparse $input $outdir/$image.vmdk

touch $outdir/$image.vmsd    # probably not needed


