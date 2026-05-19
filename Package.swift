// swift-tools-version: 5.9
import PackageDescription

// StickyKeys: `StickyKeysPane` (keyboard-lock feature as a dynamic
// library via SuiteKit, loadable by the launcher) + `StickyKeys`
// (thin @main standalone shim).
let package = Package(
    name: "StickyKeys",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "StickyKeys", targets: ["StickyKeys"]),
        .library(name: "StickyKeysPane", type: .dynamic, targets: ["StickyKeysPane"])
    ],
    dependencies: [ .package(path: "../suitekit-swift") ],
    targets: [
        .target(
            name: "StickyKeysPane",
            dependencies: [.product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/StickyKeysPane"
        ),
        .executableTarget(
            name: "StickyKeys",
            dependencies: ["StickyKeysPane", .product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/StickyKeys"
        )
    ]
)
