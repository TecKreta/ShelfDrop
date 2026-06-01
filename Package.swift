// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ShelfDrop",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "ShelfDropCore",
            path: "Sources/ShelfDropCore"
        ),
        .executableTarget(
            name: "ShelfDrop",
            dependencies: ["ShelfDropCore"],
            path: "Sources/ShelfDrop",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "KeyTapDetectorTests",
            dependencies: ["ShelfDropCore"]
        )
    ]
)
