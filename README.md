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
sudo apt install debos p7zip qemu-utils zerofree
```

Then use the script `build.sh` to build an image.

### Build from within a container

If you prefer to build from within a container, you'll need to install either
`podman` or `docker` on your machine.

Then use the script `build-in-container.sh` to build an image.

This script is simply a wrapper on top of `build.sh`, it takes care of creating
the container image if missing, and then it starts a container and performs the
build from within. Both `podman` and `docker` are supported, the script picks
one depending on what's installed on your system.

`podman` has been tested, both as root (eg. `$ sudo ./build-in-container.sh`)
and rootless (eg. `$ ./build-in-container.sh`), it works fine in both cases.

`docker` has not been tested in a while, but it's expected to work.

## Building an image

Use either `build.sh` or `build-in-container.sh`, at your preference. From
this point we'll use `build.sh` for brevity.

### Examples

The best starting point, as always, is the usage message:

```
./build.sh -h
```

Building a Kali rolling image, default desktop, default toolset. This is a raw
disk image, ie. a plain binary image of the disk. This image can be started
with QEMU, for example.

```
./build.sh
```

Build a Kali Linux image tailored for VMware. It means that it comes with the
Open VM Tools pre-installed, and the image produced is ready to be imported "as
is" in VMware. Also, we're going to build it from the last stable release of
Kali, and we'll install the GNOME desktop environment, rather than the usual
default XFCE.

```
./build.sh -v vmware -b kali-last-snapshot -D gnome
```

Build a Kali Linux image tailored for VirtualBox: it comes with the VirtualBox
guest utilities pre-installed, and the image can be imported "as is" in
VirtualBox. Moreover, we want a 150 GB virtual disk, and we'll install the
"everything" tool selection (that is, pretty much every tool in Kali).

```
./build.sh -v virtualbox -s 150 -S everything
```

Build a lightweight Kali image: no desktop environment and no default toolset.
This is a generic image, it comes with support for most VM engines out there.
We'll export it to the OVA format, suitable for both VMware and VirtualBox.
Let's also install the package `metasploit-framework`.

```
./build.sh -v generic -f ova -D headless -P metasploit-framework
```

Build a Kali image, and configure it to mimic the host system: same
username, same locale and same timezone.

```
./build.sh -L $LANG -T $(cat /etc/timezone) -U $USER:'s3cr3t!p4ssw0rd'
```

### Variants and formats

Different variants of image can be built, depending on what VM engine you want
to run the Kali image in. The VARIANT mostly defines what extra package gets
installed into the image, to add support for a particular VM engine. Then the
FORMAT defines what format for the virtual disk, and what additional metadata
files to produce.

If unset, the format (option `-f`) is automatically set according to the
variant (option `-v`). Not every combination of variant and format make sense,
so the table below tries to summarize the most common combinations.

| variant    | format     | disk format             | metadata | pack |
| ---------- | ---------- | ----------------------- | -------- | ---- |
| generic    | raw        |       raw (sparse file) |     none |      |
| generic    | ova        |    streamOptimized VMDK |      OVF |  OVA |
| generic    | ovf        |   monolithicSparse VMDK |      OVF |      |
| qemu       | qemu       |                   QCOW2 |     none |      |
| virtualbox | virtualbox |                     VDI |     VBOX |      |
| vmware     | vmware     | 2GbMaxExtentSparse VMDK |      VMX |      |

The `generic` images come with virtualization support packages pre-installed
for QEMU, VirtualBox and VMware, hence the name "generic". While other images,
that target a specific VM engine, only come with support for this particular
virtualization engine.

Only the format `ova` defines a container: the result of the build is a `.ova`
file, which is simply a tar archive. For other formats, the build produce
separate files. They can be bundled together in a 7z archive with the option
`-z`.

There is also a `rootfs` type: this is not an image. It's simply a Kali Linux
root filesystem tree, without the kernel and the bootloader, and packed in a
`.tar.gz` archive. The main use-case is to reuse it as input to build an OS
image, and it's not meant to be used outside of the build system.

### Additional configuration

You can choose the desktop environment with the `-D` option. You can also
change the default selection of tools included in the image with the `-S`
option.

You can install additional packages with the `-P` option. Either use the option
several times (eg. `-P pkg1 -P pkg2 ...`), or give a comma/space separated
value (eg. `-P "pkg1,pkg2, pkg3 pkg4"`), or a mix of both.

To set the `locale`, use the option `-L`.  Pick a value in the 1st column of
`/usr/share/i18n/SUPPORTED`, or check what's configured on your system with
`grep -v ^# /etc/locale.gen`, or simply `echo $LANG`.

To set the `timezone`, use the option `-T`. Look into `/usr/share/zoneinfo` and
pick a directory and a sub-directory. In doubt, run `tzselect` to guide you, or
look at what's configured on your system with `cat /etc/timezone`.

To set the name and password for the unprivileged user, use the option `-U`.
The value is a single string and the `:` is used to separate the username from
the password.

Pro tip: you can use `-L $LANG -T $(cat /etc/timezone) -U $USER:$USER` to
configure the image like your own machine.

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
with `./build.sh -v rootfs`, and then build an image based on this rootfs with
`./build.sh -r ROOTFS_NAME.tar.gz`. It makes sense if you plan to build several
image types, for example.

## Troubleshooting

### Not enough memory

When the scratch area gets full (ie. the `--scratchsize` value is too low), the
build might fail with this kind of error messages:

```
[...]: failed to write (No space left on device)
[...]: Cannot write: No space left on device
```

Solution: bump the value of `--scratchsize`. You can pass arguments to debos
after the special character `--`, so if you need for example 50G, you can do
`./build.sh [...] -- --scratchsize=50G`.

### Get a shell in the VM when the build fails

When debugging build failures, it's convenient to be dropped in a shell within
the VM where the build takes place. This is possible by giving the option
`--debug-shell` to debos: `./build.sh [...] -- --debug-shell`.

[debos]: https://github.com/go-debos/debos
[fakemachine]: https://github.com/go-debos/fakemachine
