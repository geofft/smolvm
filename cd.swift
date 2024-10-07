// SPDX-License-Identifier: 0BSD
import Virtualization

func configureCD(_ configuration: VZVirtualMachineConfiguration, _ isoPath: String) {
  // Booting from CD requires doing EFI boot, which requires a place
  // to store EFI variables. To support multiple simultaneous runs,
  // use C mkdtemp() to get a unique temporary filename.
  var varstoreTemplate = (NSTemporaryDirectory() + "/smolvm-efivars.XXXXXX").utf8CString
  if (varstoreTemplate.withUnsafeMutableBufferPointer { mkdtemp($0.baseAddress) }) == nil {
    perror("mkdtemp")
    exit(1)
  }
  let varstoreURL = URL(filePath: String(validatingUTF8: Array(varstoreTemplate))! + "/vars")
  let bootloader = VZEFIBootLoader()
  bootloader.variableStore = try! VZEFIVariableStore(creatingVariableStoreAt: varstoreURL)
  configuration.bootLoader = bootloader

  let disk = try! VZDiskImageStorageDeviceAttachment(
    url: URL(filePath: isoPath),
    readOnly: true
  )
  configuration.storageDevices = [VZUSBMassStorageDeviceConfiguration(attachment: disk)]
}

func cleanupEFIVars(_ configuration: VZVirtualMachineConfiguration) {
  // We don't really need EFI vars persisted between runs, so unlink
  // the file as soon as the VM starts.
  if let bootloader = configuration.bootLoader as? VZEFIBootLoader {
    let url = bootloader.variableStore!.url
    try! FileManager.default.removeItem(at: url)
    try! FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }
}
