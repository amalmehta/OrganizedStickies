// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StickiesCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "StickiesCore", targets: ["StickiesCore"]),
        .executable(name: "sorter-eval", targets: ["SorterEval"]),
    ],
    targets: [
        .target(
            name: "StickiesCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "SorterEval", dependencies: ["StickiesCore"]),
        .testTarget(
            name: "StickiesCoreTests",
            dependencies: ["StickiesCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
