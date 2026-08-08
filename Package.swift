// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScrcpyMenu",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ScrcpyMenu",
            path: "Sources/ScrcpyMenu"
        )
    ]
)
