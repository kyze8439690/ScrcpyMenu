import Foundation

final class DeviceManager: @unchecked Sendable {
    private let adbPath: String
    private let queue = DispatchQueue(label: "com.yugy.scrcpy-menu.devices")

    private var cachedDevices: [AndroidDevice] = []

    init(adbPath: String) {
        self.adbPath = adbPath
    }

    func refresh(completion: @escaping @MainActor @Sendable ([AndroidDevice]) -> Void) {
        queue.async { [self] in
            guard let output = Shell.run(adbPath, arguments: ["devices", "-l"], timeout: 5) else {
                let cached = self.cachedDevices
                Task { @MainActor in completion(cached) }
                return
            }
            let devices = Self.parseDevices(output)
            self.cachedDevices = devices
            Task { @MainActor in completion(devices) }
            for device in devices.filter({ $0.model == nil && $0.state.isUsable }).prefix(3) {
                if let name = self.fetchMarketName(serial: device.serial) {
                    self.enrich(serial: device.serial, model: name)
                }
            }
        }
    }

    private func enrich(serial: String, model: String) {
        guard let index = cachedDevices.firstIndex(where: { $0.serial == serial }) else { return }
        let old = cachedDevices[index]
        cachedDevices[index] = AndroidDevice(serial: old.serial, model: model, state: old.state)
    }

    private func fetchMarketName(serial: String) -> String? {
        let output = Shell.run(
            adbPath,
            arguments: ["-s", serial, "shell", "getprop", "ro.product.marketname"],
            timeout: 5
        )
        guard let output else { return nil }
        let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func parseDevices(_ output: String) -> [AndroidDevice] {
        var devices: [AndroidDevice] = []
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("List of devices"),
                  !trimmed.hasPrefix("*") else { continue }

            let parts = trimmed.split(separator: " ").map(String.init)
            guard parts.count >= 2 else { continue }
            let serial = parts[0]
            let stateRaw = parts[1]
            let state = DeviceState(rawValue: stateRaw) ?? .unknown

            var model: String?
            for part in parts.dropFirst(2) {
                if part.hasPrefix("model:") {
                    model = String(part.dropFirst("model:".count))
                }
            }
            devices.append(AndroidDevice(serial: serial, model: model, state: state))
        }
        return devices
    }
}

enum Shell {
    private final class TimeoutFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var _timedOut = false

        func set() {
            lock.lock()
            _timedOut = true
            lock.unlock()
        }

        var value: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _timedOut
        }
    }

    @discardableResult
    static func run(_ path: String, arguments: [String], timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let flag = TimeoutFlag()
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if process.isRunning {
                flag.set()
                process.terminate()
            }
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard !flag.value, process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
