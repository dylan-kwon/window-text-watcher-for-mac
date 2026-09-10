// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WindowTextWatcher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WindowTextWatcher",
            targets: ["WindowTextWatcher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WindowTextWatcher"
        ),
        .testTarget(
            name: "WindowTextWatcherTests",
            dependencies: ["WindowTextWatcher"]
        )
    ]
)
