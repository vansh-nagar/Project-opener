// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectOpener",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ProjectOpener",
            path: "Sources/ProjectOpener",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
