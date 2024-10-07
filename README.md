A smol VMM in Swift using Virtualization.framework
===

macOS's [Virtualization.framework](https://developer.apple.com/documentation/virtualization) is a high-level framework for building virtual machines, with device emulation, graphics, etc. built in (as opposed to the lower-level [Hypervisor.framework](https://developer.apple.com/documentation/hypervisor), which is analogous to `/dev/kvm` on Linux).

This repo is a small (< 200 lines of code) client application that can productively run Linux virtual machines. Part of the intent is that it's small enough that you don't have to trust me; you can just read all of the code. To this end, it builds with a short Makefile instead of an Xcode project. To compile, run `make`. There are two optional features so that you can read _even fewer_ lines of code: CD boot (which requires EFI) and a GUI. If you want to compile these out, use `make features=` instead of `make`.

The CLI is intended to feel vaguely familiar to a qemu user, though also some configuration might be easiest by editing the source. This VMM does not support persistent hard disks (though it would be easy to add); it is designed for stateless VMs that store any files on the host in a shared directory.

Booting a kernel
---

```
./smolvm -kernel vmlinuz -initramfs initrd.gz -append 'console=hvc0'
```

You will need an _uncompressed_ kernel; Virtualization.framework does not know how to deal with compressed kernels. If your file is `vmlinuz`, `gunzip < vmlinuz > vmlinux` should do the trick. (The initramfs can be compressed, though, because Linux loads it.)

The kernel also cannot be an EFI stub or [UKI](https://uapi-group.org/specifications/specs/unified_kernel_image/). In the Linux kernel repo is a mildly hacky shell script [scripts/extract-vmlinux](https://github.com/torvalds/linux/blob/v6.11/scripts/extract-vmlinux) that can deal with both finding a kernel inside an EFI binary and uncompressing it.

Virtualization.framework supports only virtio devices, so you need `virtio-pci` to be available either as a module or compiled in, or you won't be able to interact with the VM at all. (Note this also means it usually takes several seconds to see anything from the VM, either on the display or on the serial port.)

Booting a live CD
---

```
./smolvm -cd livecd.iso
```

Networking
---

Virtualization.framework will set up a transient, unprivileged bridge which allows making connections in either direction. Traffic from inside the VM should just work with DHCP. You can also connect from your Mac to the VM. On my machine, VMs get addresses in 192.168.64/24.

File sharing
---

When booting the VM, pass an argument like `-share src ~/src`. The first parameter is the virtio "tag" (which can be anything); the second is the path to share.

From inside the VM, mount the shared directory by giving the tag, e.g.,
```
mount -t virtiofs src /mnt
```

Note that for any serious coding work you probably want to make a case-sensitive filesystem (which is easy with APFS).

UI
---

You get _read-only_ output from the serial console (`hvc0`) on standard output. I have not yet made this read-write.

Unless you've disabled the `ui` feature or are running with `-nographic`, you'll get a window to interact with your VM. It defaults to 800x600 but it is resizable and will pass resize events onto the guest. (Note that the Linux console doesn't support being resized, but if you resize the window before the kernel boots, it will initialize with the right size.) Pressing the power button does a graceful shutdown; use Ctrl-C to force kill the VM.

Linux uses the _last_ `console=` argument as the interactive one, so you can do something like `-append 'console=hvc0 console=tty0'` (or the equivalent in GRUB) to see boot messages on stdout but primarily use the graphical console.

See also
---

Apple has perfectly good sample applications using Virtualization.framework:

* [Running Linux in a Virtual Machine](https://developer.apple.com/documentation/virtualization/running_linux_in_a_virtual_machine)
* [Running GUI Linux in a Virtual Machine](https://developer.apple.com/documentation/virtualization/running_gui_linux_in_a_virtual_machine_on_a_mac)

One of those might be more to your taste. Of course there are many other good options, including [UTM](https://mac.getutm.app/), which supports both Virtualization.framework and qemu with Hypervisor.framework.
