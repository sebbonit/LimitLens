// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ResetStat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ResetStat", targets: ["ResetStat"]),
        .library(name: "ResetStatCore", targets: ["ResetStatCore"])
    ],
    targets: [
        .target(name: "ResetStatCore"),
        .executableTarget(
            name: "ResetStat",
            dependencies: ["ResetStatCore"]
        ),
        .testTarget(
            name: "ResetStatCoreTests",
            dependencies: ["ResetStatCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ResetStatTests",
            dependencies: ["ResetStat"]
        )
    ]
)
