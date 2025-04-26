// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VolumeIconToggle",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "VolumeIconToggle", targets: ["VolumeIconToggle"])
    ],
    targets: [
        .executableTarget(
            name: "VolumeIconToggle",
            dependencies: []
        )
    ]
) 