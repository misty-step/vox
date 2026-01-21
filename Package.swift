// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Vox",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VoxApp", targets: ["VoxApp"]),
        .library(name: "VoxCore", targets: ["VoxCore"]),
        .library(name: "VoxMac", targets: ["VoxMac"]),
        .library(name: "VoxProviders", targets: ["VoxProviders"])
    ],
    targets: [
        .target(name: "VoxCore"),
        .target(name: "VoxMac", dependencies: ["VoxCore"]),
        .target(name: "VoxProviders", dependencies: ["VoxCore"]),
        .executableTarget(
            name: "VoxApp",
            dependencies: ["VoxCore", "VoxMac", "VoxProviders"]
        ),
        .testTarget(
            name: "VoxCoreTests",
            dependencies: ["VoxCore"]
        ),
        .testTarget(
            name: "VoxProvidersTests",
            dependencies: ["VoxProviders"]
        ),
        .testTarget(
            name: "VoxAppTests",
            dependencies: ["VoxApp"]
        )
    ]
)
