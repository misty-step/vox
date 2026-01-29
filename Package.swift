// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoxLocal",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VoxLocal", targets: ["VoxLocalApp"]),
    ],
    targets: [
        .target(name: "VoxLocalCore"),
        .target(name: "VoxLocalProviders", dependencies: ["VoxLocalCore"]),
        .target(name: "VoxLocalMac", dependencies: ["VoxLocalCore"]),
        .executableTarget(
            name: "VoxLocalApp",
            dependencies: ["VoxLocalCore", "VoxLocalProviders", "VoxLocalMac"]
        ),
    ]
)
