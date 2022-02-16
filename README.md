# Kali VM Image Builder

Build a Kali Linux VM image.


## How to build an image

Install the required dependencies:

    sudo apt install debos

Then build images with the script `build.sh`. Start with:

    ./build.sh -h

### Types of build

* `generic`: Build a *raw* disk image. All the virt packages are installed.
* `qemu`: Build a *qcow2* image, install virt support for QEMU.
* `virtualbox`: Build a *ova* image, install virt support for VirtualBox.
* `vmware`: Build a *vmdk* image, install virt support for VMware.
* `rootfs`: only build and pack the rootfs as a `.tar.gz`. Doesn't contain the
  kernel and bootloader. The main use-case is use it as input to build a disk
  image.

### Image configuration

* `locale` pick a value in 1st column of `/usr/share/i18n/SUPPORTED`
* `timezone` of the form `<dir>/<dir>` taken from `/usr/share/zoneinfo`



## Known limitations

* No support for vmware images yet.
* Only `amd64` build is supported for now.
