// SPDX-License-Identifier: 0BSD
import Virtualization

func configureUI(_ configuration: VZVirtualMachineConfiguration) {
  configuration.keyboards = [VZUSBKeyboardConfiguration()]
  configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

  let g = VZVirtioGraphicsDeviceConfiguration()
  g.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 800, heightInPixels: 600)]
  configuration.graphicsDevices = [g]
}

// This needs to be a global to hold ownership.
var windelegate: NSWindowDelegate?

func showUI(_ vm: VZVirtualMachine) {
  NSApplication.shared.setActivationPolicy(.regular)
  NSApp.applicationIconImage = NSImage(named: NSImage.computerName)!
  let window = NSWindow(
    contentRect: NSMakeRect(0, 0, 800, 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: true
  )
  window.collectionBehavior = .primary
  window.title = "smolvm"

  class Delegate: NSObject, NSWindowDelegate {
    var vm: VZVirtualMachine
    init(_ vm: VZVirtualMachine) {
      self.vm = vm
    }

    func windowWillResize(_ sender: NSWindow, to: NSSize) -> NSSize {
      // Accept any resize, just pass it onto the VM.
      let contentSize = sender.contentRect(forFrameRect: NSRect(origin: NSZeroPoint, size: to)).size
      try! vm.graphicsDevices[0].displays[0].reconfigure(sizeInPixels: contentSize)
      return to
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
      // Let the guest shut down gracefully.
      _ = try? vm.requestStop()
      return false
    }
  }
  windelegate = Delegate(vm)
  window.delegate = windelegate

  let view = VZVirtualMachineView()
  view.virtualMachine = vm
  window.contentView = view

  window.makeKeyAndOrderFront(Optional<NSObject>.none)

  NSApp.run()
}
