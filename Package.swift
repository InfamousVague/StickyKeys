// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickyKeys",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StickyKeys",
            path: "Sources/StickyKeys"
        )
    ]
)
