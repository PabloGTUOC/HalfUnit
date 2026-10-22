// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HalfUnitCore",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "HalfUnitCore",
            targets: ["HalfUnitCore"]
        )
    ],
    targets: [
        .target(
            name: "HalfUnitCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "HalfUnitCoreTests",
            dependencies: ["HalfUnitCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
