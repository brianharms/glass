// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glass",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Glass",
            dependencies: ["GlassKit"],
            path: "Sources/Glass",
            resources: [.copy("Resources")]
        ),
        .target(
            name: "GlassKit",
            path: "Sources/GlassKit"
        ),
        .testTarget(
            name: "GlassTests",
            dependencies: ["GlassKit"],
            path: "Tests/GlassTests"
        )
    ]
)
