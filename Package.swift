// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "lowmad",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "lowmad", targets: ["lowmad"]),
    ],
    dependencies: [
        .package(url: "git@github.com:apple/swift-argument-parser.git", from: "0.3.1"),
        .package(url: "git@github.com:onevcat/Rainbow.git", from: "3.2.0"),
        .package(url: "git@github.com:JohnSundell/Files.git", from: "4.2.0")
    ],
    targets: [
        .target(
            name: "lowmad",
            dependencies: ["Files", "Rainbow", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
        .testTarget(
            name: "lowmadTests",
            dependencies: ["lowmad"]),
    ]
)
