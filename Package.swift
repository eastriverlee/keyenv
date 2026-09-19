// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "keyenv",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "keyenv")]
)
