// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeTerm",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ClaudeTerm",
            targets: ["ClaudeTerm"]
        )
    ],
    dependencies: [
        // SSH library for iOS
        .package(url: "https://github.com/NMSSH/NMSSH.git", from: "2.3.1"),
        // Terminal emulator for VT100/xterm support
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "ClaudeTerm",
            dependencies: [
                "NMSSH",
                "SwiftTerm"
            ],
            path: "ClaudeTerm"
        )
    ]
)
