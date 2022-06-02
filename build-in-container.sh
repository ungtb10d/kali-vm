#!/bin/bash

set -eu

IMAGE=kali-rolling/vm-builder

if [ -x /usr/bin/podman ]; then
    PODMAN=podman
    RUN_OPTS="--log-driver none"
elif [ -x /usr/bin/docker ]; then
    PODMAN=docker
    RUN_OPTS=
else
    echo "ERROR: No container engine detected, aborting." >&2
    exit 1
fi

if [ $PODMAN = podman ] && [ $(id -u) -ne 0 ]; then
    echo "WARNING: Rootless podman container is not recommended to build Kali VM." >&2
    echo "WARNING: Please consider running as the root user for best performance." >&2
fi

if ! $PODMAN inspect --type image $IMAGE >/dev/null 2>&1; then
    $PODMAN build -t $IMAGE .
fi

$PODMAN run --interactive --rm --tty \
    --device /dev/kvm \
    --group-add $(stat -c "%g" /dev/kvm) \
    --net host \
    --user $(stat -c "%u:%g" .) \
    --volume $(pwd):/recipes \
    --workdir /recipes \
    $RUN_OPTS $IMAGE ./build.sh "$@"
