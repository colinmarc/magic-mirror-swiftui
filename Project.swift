import ProjectDescription

let appVersion = "v0.1.5"

let project = Project(
    name: "MagicMirror",
    packages: [
        .package(path: "MMClientCommon"),
        .remote(
            url: "https://github.com/apple/swift-collections.git",
            requirement: .upToNextMajor(from: "1.1.2")),
        .remote(
            url: "https://github.com/computer-graphics-tools/core-video-tools",
            requirement: .upToNextMajor(from: "0.1.0")),
        .remote(
            url: "https://github.com/alta/swift-opus",
            requirement: .revision("6f3cb6bd3ffed1fe5f06d00a962d5c191a50daf8")),
        .remote(
            url: "https://github.com/michaeltyson/TPCircularBuffer",
            requirement: .upToNextMajor(from: "1.6.2")),
    ],
    targets: [
        .target(
            name: "MagicMirror",
            destinations: .macOS,
            product: .app,
            bundleId: "com.colinmarc.MagicMirror",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "NSMainStoryboardFile": .string(""),
                "LSApplicationCategory": .string("public.app-category.games"),
                "CFBundleShortVersionString": .string(appVersion),
                "GCSupportsControllerUserInteraction": .boolean(true),
            ]),
            sources: ["MagicMirror/**"],
            resources: ["MagicMirror/Assets.xcassets"],
            dependencies: [
                .package(product: "MMClientCommon"),
                .package(product: "Collections"),
                .package(product: "CoreVideoTools"),
                .package(product: "Opus"),
                .package(product: "TPCircularBuffer"),
            ]
        )
    ]
)
