#!/bin/sh

set -eu

fail() { echo "$@" >&2; exit 1; }
usage() { fail "Usage: $(basename $0) OVF VMDK"; }

# Validate arguments

[ $# -eq 2 ] || usage

ovf=$1; shift
vmdk=$1; shift

[ ${ovf##*.} = ovf ] || fail "Invalid input file '$ovf'"
[ ${vmdk##*.} = vmdk ] || fail "Invalid input file '$vmdk'"

# Create the manifest (.mf)

mf=${ovf%.*}.mf

ovf_sha=$(sha1sum $ovf | awk '{print $1}')
vmdk_sha=$(sha1sum $vmdk | awk '{print $1}')

cat << EOF > $mf
SHA1 ($(basename $ovf)) = $ovf_sha
SHA1 ($(basename $vmdk)) = $vmdk_sha
EOF

# Create the archive (.ova).
# Order matters. The .ovf must come first. The .mf comes either
# second or last. For more details, refer to the OVF specification:
# https://www.dmtf.org/sites/default/files/standards/documents/DSP0243_1.1.0.pdf

ova=${ovf%.*}.ova

tar -cvf $ova $ovf $vmdk $mf
