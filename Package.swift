// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VolumeControlOverlayToggle",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "VolumeControlOverlayToggle", targets: ["VolumeControlOverlayToggle"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.1.4")
    ],
    targets: [
        .executableTarget(
            name: "VolumeControlOverlayToggle",
            dependencies: [
                .product(name: "HotKey", package: "HotKey")
            ]
        )
    ]
) 