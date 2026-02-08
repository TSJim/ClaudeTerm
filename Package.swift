// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeTerm",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ClaudeTerm",
            targets: ["ClaudeTerm"]
        )
    ],
    dependencies: [
        // SSH library - pure Swift, SPM native
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0"),
        // Terminal emulator for VT100/xterm support
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeTerm",
            dependencies: [
                .product(name: "Citadel", package: "Citadel"),
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "ClaudeTerm",
            exclude: ["Info.plist", "Resources"]
        )
    ]
)
