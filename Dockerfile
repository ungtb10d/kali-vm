FROM docker.io/kalilinux/kali-rolling

RUN apt-get update \
 && apt-get install --no-install-recommends -y \
    debos linux-image-amd64 p7zip parted qemu-utils xz-utils \
 && apt-get clean
