// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AABTool",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AABTool", targets: ["AABTool"]),
    ],
    targets: [
        .executableTarget(
            name: "AABTool",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
