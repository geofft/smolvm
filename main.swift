// SPDX-License-Identifier: 0BSD
import Virtualization

let configuration = VZVirtualMachineConfiguration()

// The default memory size is 4 MB! If booting from a kernel, make sure
// you have at least enough memory for the kernel and initrd themselves
// or the VM will fail to even initialize.
configuration.memorySize = 8 * 1024 * 1024 * 1024

// Virtualization.framework supports both "console attachments" and
// "serial attachments," but as far as I can tell, they both show up in
// the guest as virtio console devices (PCI 1af4:1043) and they seem to
// work the same.
let serialconfig = VZVirtioConsoleDeviceSerialPortConfiguration()
serialconfig.attachment = try! VZFileSerialPortAttachment(
  url: URL(filePath: "/dev/stdout"), append: true)
configuration.serialPorts = [serialconfig]

let net = VZVirtioNetworkDeviceConfiguration()
net.attachment = VZNATNetworkDeviceAttachment()
configuration.networkDevices = [net]

// This sets up the file share for the Rosetta binfmt-misc handler.
let rosetta = VZVirtioFileSystemDeviceConfiguration(tag: "rosetta")
rosetta.share = try! VZLinuxRosettaDirectoryShare()
configuration.directorySharingDevices = [rosetta]

#if ui
  var graphics = true
#else
  var graphics = false
#endif

var i = 1
while i < CommandLine.arguments.count {
  switch CommandLine.arguments[i] {
  #if cd
    case "-cd":
      configureCD(configuration, CommandLine.arguments[i + 1])
      i += 2
  #endif
  case "-kernel":
    configuration.bootLoader = VZLinuxBootLoader(
      kernelURL: URL(filePath: CommandLine.arguments[i + 1]))
    i += 2
  case "-initrd", "-initramfs":
    (configuration.bootLoader! as! VZLinuxBootLoader).initialRamdiskURL = URL(
      filePath: CommandLine.arguments[i + 1])
    i += 2
  case "-append":
    (configuration.bootLoader! as! VZLinuxBootLoader).commandLine = CommandLine.arguments[i + 1]
    i += 2
  case "-share":
    let fs = VZVirtioFileSystemDeviceConfiguration(tag: CommandLine.arguments[i + 1])
    fs.share = VZSingleDirectoryShare(
      directory: VZSharedDirectory(
        url: URL(filePath: CommandLine.arguments[i + 2]), readOnly: false)
    )
    configuration.directorySharingDevices.append(fs)
    i += 3
  case "-nographic":
    graphics = false
    i += 1
  default:
    print("Unknown argument \(CommandLine.arguments[i])")
    exit(1)
  }
}

#if ui
  if graphics {
    configureUI(configuration)
  }
#endif

try! configuration.validate()

let vm = VZVirtualMachine(configuration: configuration)

class Delegate: NSObject, VZVirtualMachineDelegate {
  func guestDidStop(_ vm: VZVirtualMachine) {
    exit(0)
  }

  func virtualMachine(_ vm: VZVirtualMachine, didStopWithError error: any Error) {
    print("stopped with \(error)")
    exit(1)
  }
}

let delegate = Delegate()
vm.delegate = delegate

vm.start { (result) in
  print(result)
  #if cd
    cleanupEFIVars(configuration)
  #endif
}

if graphics {
  #if ui
    showUI(vm)
  #endif
} else {
  RunLoop.main.run()
}
