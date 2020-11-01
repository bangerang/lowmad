// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lowmad",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "lowmad", targets: ["Lowmad"]),
    ],
    dependencies: [
        .package(url: "git@github.com:onevcat/Rainbow.git", from: "3.2.0"),
        .package(url: "git@github.com:JohnSundell/Files.git", from: "4.2.0"),
        .package(url: "https://github.com/jakeheis/SwiftCLI", from: "6.0.0")
    ],
    targets: [
        .target(name: "Lowmad", dependencies: ["LowmadCLI"]),
        .target(name: "LowmadCLI", dependencies: ["Rainbow", "SwiftCLI", "LowmadKit"]),
        .target(name: "Shell", dependencies: ["SwiftCLI"]),
        .target(name: "LowmadKit", dependencies: ["Rainbow", "SwiftCLI", "Files", "Git", "Shell", "World"]),
        .target(name: "Git", dependencies: ["Shell"]),
        .target(name: "World", dependencies: ["Git", "Files", "SwiftCLI"]),
        .testTarget(
            name: "LowmadTests",
            dependencies: ["Lowmad", "World"]),
    ]
)
