import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private var dependencyStatus: DependencyStatus?
    private var deviceManager: DeviceManager?
    private var scrcpyManager: ScrcpyManager?
    private var devices: [AndroidDevice] = []
    private var didShowDependencyAlert = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "ScrcpyMenu") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "SCR"
            }
        }

        menu.delegate = self
        statusItem.menu = menu

        dependencyStatus = DependencyChecker.check()
        if let status = dependencyStatus, status.isReady {
            let deviceManager = DeviceManager(adbPath: status.adbPath!)
            let scrcpyManager = ScrcpyManager(scrcpyPath: status.scrcpyPath!, adbPath: status.adbPath!)
            scrcpyManager.onStateChange = { [weak self] in self?.rebuildMenu() }
            scrcpyManager.onFailure = { [weak self] failure in self?.showFailureAlert(failure) }
            self.deviceManager = deviceManager
            self.scrcpyManager = scrcpyManager
            refreshDevices()
        } else {
            showDependencyAlert()
        }
        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scrcpyManager?.stopAll()
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
        refreshDevices()
    }

    // MARK: - Menu

    private func rebuildMenu() {
        menu.removeAllItems()

        guard let status = dependencyStatus, status.isReady else {
            let missing = dependencyStatus?.missingTools.joined(separator: ", ") ?? "scrcpy, adb"
            let item = NSMenuItem(title: "Missing: \(missing)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            let hint = NSMenuItem(title: "brew install scrcpy android-platform-tools", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
            menu.addItem(.separator())
            menu.addItem(makeItem("Quit", action: #selector(quit)))
            return
        }

        if devices.isEmpty {
            let item = NSMenuItem(title: "No devices", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let nameCounts = Dictionary(grouping: devices, by: { $0.displayName })
                .mapValues { $0.count }
            for device in devices {
                var title = device.displayName
                if (nameCounts[device.displayName] ?? 0) > 1 {
                    title += " (\(device.serial))"
                }
                if !device.state.isUsable {
                    title += " — \(device.state.displayText)"
                }
                let running = scrcpyManager?.isRunning(serial: device.serial) ?? false
                if running {
                    title = "● " + title
                }
                let item = NSMenuItem(title: title, action: #selector(toggleDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.serial
                item.isEnabled = device.state.isUsable
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(makeItem("Refresh Devices", action: #selector(refreshDevices)))
        menu.addItem(makeItem("Open Logs Folder", action: #selector(openLogsFolder)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit", action: #selector(quit)))
    }

    private func makeItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func toggleDevice(_ sender: NSMenuItem) {
        guard let serial = sender.representedObject as? String,
              let device = devices.first(where: { $0.serial == serial }) else { return }
        scrcpyManager?.toggle(device: device)
    }

    @objc private func refreshDevices() {
        deviceManager?.refresh { [weak self] devices in
            self?.devices = devices
            self?.rebuildMenu()
        }
    }

    @objc private func openLogsFolder() {
        NSWorkspace.shared.open(ScrcpyManager.logsDirectory)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Alerts

    private func showDependencyAlert() {
        guard !didShowDependencyAlert else { return }
        didShowDependencyAlert = true
        let missing = dependencyStatus?.missingTools.joined(separator: ", ") ?? "scrcpy, adb"
        let alert = NSAlert()
        alert.messageText = "Missing Dependencies"
        alert.informativeText = "Could not find: \(missing)\n\nInstall with:\nbrew install scrcpy android-platform-tools"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showFailureAlert(_ failure: ScrcpyFailure) {
        let alert = NSAlert()
        alert.messageText = "scrcpy failed to start"
        alert.informativeText = "Device: \(failure.serial)\nExit code: \(failure.exitCode)\n\n\(failure.outputTail)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
