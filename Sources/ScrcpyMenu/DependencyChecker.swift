import Foundation

struct DependencyStatus {
    let scrcpyPath: String?
    let adbPath: String?

    var isReady: Bool { scrcpyPath != nil && adbPath != nil }

    var missingTools: [String] {
        var missing: [String] = []
        if scrcpyPath == nil { missing.append("scrcpy") }
        if adbPath == nil { missing.append("adb") }
        return missing
    }
}

enum DependencyChecker {
    private static let candidateDirs = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
    ]

    private static let adbExtraDirs = [
        NSHomeDirectory() + "/Library/Android/sdk/platform-tools",
    ]

    static func check() -> DependencyStatus {
        DependencyStatus(
            scrcpyPath: locate("scrcpy", extraDirs: []),
            adbPath: locate("adb", extraDirs: adbExtraDirs)
        )
    }

    static func locate(_ tool: String, extraDirs: [String]) -> String? {
        let fm = FileManager.default
        for dir in candidateDirs + extraDirs {
            let path = dir + "/" + tool
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let path = String(dir) + "/" + tool
                if fm.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }
}
