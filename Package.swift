// swift-tools-version: 5.9
//
// Shotjoy — a fast, local-only screenshot tool for macOS.
// GNU AGPL-3.0. See LICENSE.

import PackageDescription

var products: [Product] = []
var targets: [Target] = [
    .target(
        name: "ShotjoyCore",
        path: "Sources/ShotjoyCore"
    ),
    .testTarget(
        name: "ShotjoyCoreTests",
        dependencies: ["ShotjoyCore"],
        path: "Tests/ShotjoyCoreTests"
    )
]

#if os(macOS)
products.append(.executable(name: "Shotjoy", targets: ["Shotjoy"]))
targets.append(
    .executableTarget(
        name: "Shotjoy",
        dependencies: ["ShotjoyCore"],
        path: "Sources/Shotjoy",
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("SwiftUI"),
            .linkedFramework("Carbon"),
            .linkedFramework("CoreGraphics"),
            .linkedFramework("ImageIO"),
            .linkedFramework("UniformTypeIdentifiers"),
            .linkedFramework("Vision"),
            .linkedFramework("ScreenCaptureKit"),
            .linkedFramework("ServiceManagement"),
            .linkedFramework("CoreText")
        ]
    )
)
#endif

let package = Package(
    name: "Shotjoy",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    targets: targets
)
