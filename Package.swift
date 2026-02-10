// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Vox",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vox", targets: ["VoxApp"]),
        .executable(name: "VoxBenchmarks", targets: ["VoxBenchmarks"]),
    ],
    targets: [
        .target(name: "VoxCore"),
        .target(name: "VoxProviders", dependencies: ["VoxCore"]),
        .target(name: "VoxMac", dependencies: ["VoxCore"]),
        .target(
            name: "VoxAppKit",
            dependencies: ["VoxCore", "VoxProviders", "VoxMac"]
        ),
        .executableTarget(
            name: "VoxApp",
            dependencies: ["VoxAppKit"]
        ),
        .executableTarget(
            name: "VoxBenchmarks",
            dependencies: ["VoxCore", "VoxProviders"]
        ),
        .testTarget(
            name: "VoxProvidersTests",
            dependencies: ["VoxProviders"]
        ),
        .testTarget(
            name: "VoxCoreTests",
            dependencies: ["VoxCore"]
        ),
        .testTarget(
            name: "VoxAppTests",
            dependencies: ["VoxAppKit", "VoxCore", "VoxMac"]
        ),
    ]
)
