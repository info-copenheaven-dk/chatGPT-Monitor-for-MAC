// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuotaMonitor",
    platforms: [.macOS("27.0")],
    targets: [
        .executableTarget(name: "QuotaMonitor")
    ]
)
