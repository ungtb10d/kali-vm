# Kali VM Image Builder

Recipes to build Kali Linux VM images.



## Prerequisites

The images are built using the OS image builder named [debos][].

Let's install it via APT:

    sudo apt install debos

[debos]: https://github.com/go-debos/debos


## Build an image

The script `build.sh` is a wrapper on top of debos. Get started with:

    ./build.sh -h

Then build a default image with:

    ./build.sh

### Types of build

Different types of images can be built using the option `-t`:

* `generic`: Build a *raw* disk image, install all virt support packages.
* `qemu`: Build a *qcow2* image, install virt support for QEMU.
* `virtualbox`: Build a *ova* image, install virt support for VirtualBox.
* `vmware`: Build a *vmdk* image, install virt support for VMware.
* `rootfs`: only build and pack the rootfs as a `.tar.gz`. Doesn't contain the
  kernel and bootloader. The main use-case is to reuse it as input to build a
  disk image.

### Image configuration (not exposed by build.sh yet)

* `locale` pick a value in 1st column of `/usr/share/i18n/SUPPORTED`
* `timezone` of the form `<dir>/<dir>` taken from `/usr/share/zoneinfo`

### Caching proxy configuration

When building OS images, it's useful to have a caching mechanism in place, to
avoid having to download all the packages from Internet, again and again. To
this effect, the build script attempts to detect well-known caching proxies
that would be running on the local host, such as apt-cacher-ng, approx and
squid-deb-proxy.

To override this detection, you can export the variable `http_proxy` yourself.
However, you should know that the build happens within a QEMU VM, therefore
`localhost` in the build environment refers to the VM, not to the host. If you
want to reach the host from the VM, you probably want to use `http://10.0.2.2`.

For example, if you want to use a proxy that is running on your machine on the
port 9876, use `export http_proxy=10.0.2.2:9876`. To make sure that no proxy is
used, `export http_proxy=`.

Also refer to <https://github.com/go-debos/debos#environment-variables> for
more details.



## Known limitations

* Only `amd64` build is supported for now (nothing else was tested).
* VMware build is not ready yet.
