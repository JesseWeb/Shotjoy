// swift-tools-version: 5.9
//
// ShotDesk — a WeChat-style screenshot tool for macOS.
// GNU AGPL-3.0. See LICENSE.

import PackageDescription

var products: [Product] = []
var targets: [Target] = [
    .target(
        name: "ShotDeskCore",
        path: "Sources/ShotDeskCore"
    ),
    .testTarget(
        name: "ShotDeskCoreTests",
        dependencies: ["ShotDeskCore"],
        path: "Tests/ShotDeskCoreTests"
    )
]

#if os(macOS)
products.append(.executable(name: "ShotDesk", targets: ["ShotDesk"]))
targets.append(
    .executableTarget(
        name: "ShotDesk",
        dependencies: ["ShotDeskCore"],
        path: "Sources/ShotDesk",
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
    name: "ShotDesk",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    targets: targets
)
