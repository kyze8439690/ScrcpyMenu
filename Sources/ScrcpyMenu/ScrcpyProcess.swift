import Foundation

struct ScrcpyFailure {
    let serial: String
    let exitCode: Int32
    let outputTail: String
}

final class ScrcpyManager: @unchecked Sendable {
    private struct Instance {
        let process: Process
        let logURL: URL
        let startTime: Date
    }

    private let scrcpyPath: String
    private let adbPath: String
    private var instances: [String: Instance] = [:]
    private let lock = NSLock()

    /// Called on main thread whenever a device starts or stops.
    var onStateChange: (() -> Void)?
    /// Called on main thread when scrcpy exits abnormally shortly after launch.
    var onFailure: ((ScrcpyFailure) -> Void)?

    static let logsDirectory: URL = {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ScrcpyMenu", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    init(scrcpyPath: String, adbPath: String) {
        self.scrcpyPath = scrcpyPath
        self.adbPath = adbPath
    }

    func isRunning(serial: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return instances[serial] != nil
    }

    func toggle(device: AndroidDevice) {
        if isRunning(serial: device.serial) {
            stop(serial: device.serial)
        } else {
            start(device: device)
        }
    }

    func start(device: AndroidDevice) {
        lock.lock()
        guard instances[device.serial] == nil else {
            lock.unlock()
            return
        }
        lock.unlock()

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let safeSerial = device.serial.replacingOccurrences(of: ":", with: "-")
        let logURL = Self.logsDirectory.appendingPathComponent("\(safeSerial)-\(timestamp).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        guard let logHandle = try? FileHandle(forWritingTo: logURL) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: scrcpyPath)
        process.arguments = ["-s", device.serial, "--window-title=\(device.displayName)"]
        var env = ProcessInfo.processInfo.environment
        let adbDir = URL(fileURLWithPath: adbPath).deletingLastPathComponent().path
        env["PATH"] = adbDir + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        env["ADB"] = adbPath
        process.environment = env
        process.standardOutput = logHandle
        process.standardError = logHandle

        let startTime = Date()
        let serial = device.serial
        process.terminationHandler = { [weak self] proc in
            try? logHandle.close()
            guard let self else { return }
            self.lock.lock()
            self.instances.removeValue(forKey: serial)
            self.lock.unlock()
            let uptime = Date().timeIntervalSince(startTime)
            let exitCode = proc.terminationStatus
            let failure: ScrcpyFailure? = (uptime < 3 && exitCode != 0)
                ? ScrcpyFailure(serial: serial, exitCode: exitCode, outputTail: Self.readTail(of: logURL))
                : nil
            DispatchQueue.main.async {
                self.onStateChange?()
                if let failure { self.onFailure?(failure) }
            }
        }

        do {
            try process.run()
        } catch {
            try? logHandle.close()
            let failure = ScrcpyFailure(serial: serial, exitCode: -1, outputTail: error.localizedDescription)
            DispatchQueue.main.async { self.onFailure?(failure) }
            return
        }

        lock.lock()
        instances[serial] = Instance(process: process, logURL: logURL, startTime: startTime)
        lock.unlock()
        DispatchQueue.main.async { self.onStateChange?() }
    }

    func stop(serial: String) {
        lock.lock()
        let instance = instances[serial]
        lock.unlock()
        guard let instance, instance.process.isRunning else { return }
        instance.process.terminate()
    }

    func stopAll() {
        lock.lock()
        let all = Array(instances.values)
        lock.unlock()

        for instance in all where instance.process.isRunning {
            instance.process.terminate()
        }
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if all.allSatisfy({ !$0.process.isRunning }) { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        for instance in all where instance.process.isRunning {
            kill(instance.process.processIdentifier, SIGKILL)
        }
    }

    private static func readTail(of url: URL, maxBytes: Int = 4096) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let size = handle.seekToEndOfFile()
        let offset = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.suffix(5).joined(separator: "\n")
    }
}
