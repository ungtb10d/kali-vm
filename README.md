# Kali VM Image Builder

Recipes to build Kali Linux Virtual Machine (VM) images.

## Prerequisites

Make sure that the Git repo is cloned locally:

```
sudo apt install git
git clone https://gitlab.com/kalilinux/build-scripts/kali-vm.git
cd kali-vm/
```

Two build methods are possible: either build straight from your machine, or
build from within a container. Either way, the build actually happens from
within a virtual machine that is created on-the-fly by the build tool
[debos][]. It uses [fakemachine][] under the hood, which in turn relies on
QEMU/KVM.

### User setup

You must be part of the group `kvm`. You can check that with:

```
grep kvm /etc/group
```

If your username doesn't appear in the line returned,it means that you're not
in the group, and you must add yourself to the `kvm` group:

```
sudo adduser $USER kvm
```

Then **log out and log back in** for the change to take effect.

### Build from the host

If building straight from your machine, you'll need to install `debos` and a
little more:

```
sudo apt install debos p7zip qemu-utils
```

Then use the script `build.sh` to build an image.

### Build from within a container

If you prefer to build from within a container, you'll need either `podman` or
`docker` to be installed on your machine.

Then use the script `build-in-container.sh` to build an image.

This script is simply a wrapper on top of `build.sh`, it takes care of creating
the container image if missing, and then it starts a container and performs the
build from within. Both `podman` and `docker` are supported.

If you go with `podman`, you must run the script as root. If you go with
`docker`, run as root if your user is not part of the `docker` group, run
normally otherwise.

Saying it again, with code:

```
# if podman
$ sudo ./build-in-container.sh
# if docker, user not in docker group
$ sudo ./build-in-container.sh
# if docker, user in docker group
$ ./build-in-container.sh
```

## Building an image

### Get started

Use either `build.sh` or `build-in-container.sh`, at your preference. From
this point we'll use `build.sh` for brevity.

The best starting point, as always, is the usage message:

```
./build.sh -h
```

Building a Kali rolling image can be done with:

```
./build.sh
```

### Types of build

Different types of images can be built using the option `-t`. The image type
decides what virtualization support is installed in the image, and the format
to use to export the image.

| image type  | disk format             | metadata | container |
| ----------- | ----------------------- | -------- | --------- |
| generic-ova |    streamOptimized VMDK |      OVF |       OVA |
| generic-ovf |   monolithicSparse VMDK |      OVF |           |
| generic-raw |       raw (sparse file) |     none |           |
| qemu        |                   QCOW2 |     none |           |
| virtualbox  |                     VDI |     VBOX |           |
| vmware      | 2GbMaxExtentSparse VMDK |      VMX |           |

The `generic-*` images come with virtualization support packages pre-installed
for QEMU, VirtualBox and VMware, hence the name "generic". While other images,
that target a specific VM engine, only come with support for this particular
virtualization engine.

Only the image `generic-ova` defines a container: the result of the build is a
`.ova` file, which is simply a tar archive. For other image types, the build
produce separate files. They can be bundled together in a 7z archive with the
option `-z`.

There is also a `rootfs` type: this is not an image. It's simply a Kali Linux
root filesystem tree, without the kernel and the bootloader, and packed in a
`.tar.gz` archive. The main use-case is to reuse it as input to build an OS
image.

### Additional configuration

You can install additional packages with the `-p` option. Either use the option
several times (eg. `-p pkg1 -p pkg2 ...`), or give a comma/space separated
value (eg. `-p "pkg1,pkg2, pkg3 pkg4"`), or a mix of both.

### Image configuration (not exposed by build.sh yet)

* `locale` pick a value in 1st column of `/usr/share/i18n/SUPPORTED`
* `timezone` of the form `<dir>/<dir>` taken from `/usr/share/zoneinfo`. In
  doubt, run `tzselect` to guide you.

### Caching proxy configuration

When building OS images, it's useful to have a caching mechanism in place, to
avoid having to download all the packages from Internet, again and again. To
this effect, the build script attempts to detect well-known caching proxies
that would be running on the local host, such as apt-cacher-ng, approx and
squid-deb-proxy.

To override this detection, you can export the variable `http_proxy` yourself.
However, you should remember that the build happens within a QEMU Virtual
Machine, therefore `localhost` in the build environment refers to the VM, not
to the host. If you want to reach the host from the VM, you probably want to
use `http://10.0.2.2`.

For example, if you want to use a proxy that is running on your machine on the
port 9876, use `export http_proxy=10.0.2.2:9876`. If you want to make sure that
no proxy is used, `export http_proxy=`.

Also refer to <https://github.com/go-debos/debos#environment-variables> for
more details.

### Building and reusing a rootfs

It's possible to break the build in two steps. You can first build a rootfs
with `./build.sh -t rootfs`, and then build an image based on this rootfs with
`./build.sh -r ROOTFS_NAME.tar.gz`. It makes sense if you plan to build several
image types, for example.

## Known limitations

* Only `amd64` build is supported for now (nothing else was tested).
* VMware build is not ready yet.

[debos]: https://github.com/go-debos/debos
[fakemachine]: https://github.com/go-debos/fakemachine
