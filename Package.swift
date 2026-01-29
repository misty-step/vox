// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Vox",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vox", targets: ["VoxApp"]),
    ],
    targets: [
        .target(name: "VoxCore"),
        .target(name: "VoxProviders", dependencies: ["VoxCore"]),
        .target(name: "VoxMac", dependencies: ["VoxCore"]),
        .executableTarget(
            name: "VoxApp",
            dependencies: ["VoxCore", "VoxProviders", "VoxMac"]
        ),
    ]
)
