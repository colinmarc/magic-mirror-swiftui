// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MMClientCommon",
    platforms: [
        .macOS(.v10_15),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "MMClientCommon",
            targets: ["MMClientCommon", "RustFFI"])
    ],
    targets: [
        .target(
            name: "MMClientCommon",
            dependencies: ["RustFFI"],
            path: "build/Sources"
        ),
        .binaryTarget(
            name: "RustFFI",
            path: "build/MMClientCommon.xcframework"
        ),
    ]
)
