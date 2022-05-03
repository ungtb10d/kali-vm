#!/bin/sh

set -eu

image=$1

echo "INFO: Generate $image.qcow2"
qemu-img convert -O qcow2 $image.raw $image.qcow2
