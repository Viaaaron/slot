import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var controller: SlotController!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.log("Slot launched")
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▣"
        statusItem.button?.toolTip = "Slot clipboard ring"

        controller = SlotController { [weak self] in self?.refreshMenu() }
        refreshMenu()
        controller.start()

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            if self.controller.isTrusted {
                self.controller.start()
                self.refreshMenu()
                Diagnostics.log("Accessibility trusted; controller active")
                timer.invalidate()
            }
        }
    }

    private func refreshMenu() {
        guard statusItem != nil, controller != nil else { return }
        let menu = NSMenu()

        let active = controller.isListening
            ? "Slot is active"
            : (controller.isTrusted ? "Starting Slot…" : "Accessibility access required")
        let status = NSMenuItem(title: active, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        if controller.entries.isEmpty {
            let empty = NSMenuItem(title: "No saved slots yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, entry) in controller.entries.enumerated() {
                let marker = controller.cycleIndex == index ? "●" : " "
                let item = NSMenuItem(title: "\(marker) \(index + 1)  \(entry.preview)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let permission = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)

        let clear = NSMenuItem(title: "Clear Saved Slots", action: #selector(clearSlots), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !controller.entries.isEmpty
        menu.addItem(clear)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Slot", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func openAccessibilitySettings() {
        controller.requestAccessibilityIfNeeded()
        controller.openAccessibilitySettings()
    }

    @objc private func clearSlots() {
        controller.clearSlots()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
