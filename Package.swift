// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Vox",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vox", targets: ["VoxApp"]),
        .executable(name: "VoxBenchmarks", targets: ["VoxBenchmarks"]),
        .executable(name: "VoxPerfAudit", targets: ["VoxPerfAudit"]),
        .library(name: "VoxPerfAuditKit", targets: ["VoxPerfAuditKit"]),
        .library(name: "VoxCore", targets: ["VoxCore"]),
        .library(name: "VoxProviders", targets: ["VoxProviders"]),
        .library(name: "VoxMac", targets: ["VoxMac"]),
        .library(name: "VoxDiagnostics", targets: ["VoxDiagnostics"]),
        .library(name: "VoxPipeline", targets: ["VoxPipeline"]),
        .library(name: "VoxUI", targets: ["VoxUI"]),
        .library(name: "VoxSession", targets: ["VoxSession"]),
        .library(name: "VoxAppKit", targets: ["VoxAppKit"]),
    ],
    targets: [
        .target(name: "VoxCore"),
        .target(name: "VoxProviders", dependencies: ["VoxCore"]),
        .target(name: "VoxMac", dependencies: ["VoxCore"]),
        .target(name: "VoxDiagnostics", dependencies: ["VoxCore"]),
        .target(name: "VoxPipeline", dependencies: ["VoxCore", "VoxDiagnostics"]),
        .target(
            name: "VoxUI",
            dependencies: ["VoxCore", "VoxMac", "VoxDiagnostics"]
        ),
        .target(
            name: "VoxSession",
            dependencies: ["VoxCore", "VoxProviders", "VoxMac", "VoxDiagnostics", "VoxPipeline", "VoxUI"]
        ),
        .target(name: "VoxPerfAuditKit"),
        .target(
            name: "VoxAppKit",
            dependencies: ["VoxCore", "VoxProviders", "VoxMac", "VoxDiagnostics", "VoxPipeline", "VoxUI", "VoxSession"]
        ),
        .executableTarget(
            name: "VoxApp",
            dependencies: ["VoxAppKit"]
        ),
        .executableTarget(
            name: "VoxBenchmarks",
            dependencies: ["VoxCore", "VoxProviders", "VoxPipeline"]
        ),
        .executableTarget(
            name: "VoxPerfAudit",
            dependencies: ["VoxPerfAuditKit", "VoxAppKit", "VoxCore", "VoxProviders", "VoxMac", "VoxPipeline"]
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
            name: "VoxPerfAuditKitTests",
            dependencies: ["VoxPerfAuditKit"]
        ),
        .testTarget(
            name: "VoxDiagnosticsTests",
            dependencies: ["VoxDiagnostics"]
        ),
        .testTarget(
            name: "VoxPipelineTests",
            dependencies: ["VoxPipeline", "VoxCore"]
        ),
        .testTarget(
            name: "VoxUITests",
            dependencies: ["VoxUI", "VoxCore", "VoxMac", "VoxDiagnostics"]
        ),
        .testTarget(
            name: "VoxSessionTests",
            dependencies: ["VoxSession", "VoxCore", "VoxMac", "VoxPipeline"]
        ),
        .testTarget(
            name: "VoxAppTests",
            dependencies: ["VoxAppKit", "VoxCore", "VoxDiagnostics", "VoxMac", "VoxPipeline"]
        ),
    ]
)
