// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LightL",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "LightL", targets: ["LightL"])
    ],
    targets: [
        .executableTarget(
            name: "LightL",
            path: "Sources/LightL",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LightLTests",
            dependencies: ["LightL"],
            path: "Tests/LightLTests"
        )
    ]
)
