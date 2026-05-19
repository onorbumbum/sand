// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sand",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "sand", targets: ["sand"]),
        .library(name: "SandCore", targets: ["SandCore"])
    ],
    targets: [
        .executableTarget(
            name: "sand",
            dependencies: ["SandCore"]
        ),
        .target(name: "SandCore"),
        .testTarget(
            name: "SandCoreTests",
            dependencies: ["SandCore"]
        )
    ]
)
