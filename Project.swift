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
            url: "https://github.com/ChimeHQ/KeyCodes.git",
            requirement: .upToNextMajor(from: "1.0.3")),
        .remote(
            url: "https://github.com/alta/swift-opus",
            requirement: .revision("6f3cb6bd3ffed1fe5f06d00a962d5c191a50daf8")),
        .remote(
            url: "https://github.com/michaeltyson/TPCircularBuffer",
            requirement: .upToNextMajor(from: "1.6.2")),
    ],
    settings: .settings(base: SettingsDictionary().automaticCodeSigning(devTeam: "5H2235KKSQ")),
    targets: [
        .target(
            name: "MagicMirror",
            destinations: [.mac, .appleTv],
            product: .app,
            bundleId: "com.colinmarc.MagicMirror",
            deploymentTargets: .multiplatform(macOS: "14.0", tvOS: "18.0"),
            infoPlist: .extendingDefault(with: [
                "NSMainStoryboardFile": .string(""),
                "LSApplicationCategory": .string("public.app-category.games"),
                "CFBundleShortVersionString": .string(appVersion),
                "GCSupportsControllerUserInteraction": .boolean(true),
            ]),
            sources: [
                .glob(
                    "MagicMirror/**", excluding: ["MagicMirror/macOS/**", "MagicMirror/tvOS/**"]),
                .glob("MagicMirror/macOS/**", compilationCondition: .when([.macos])),
                .glob("MagicMirror/tvOS/**", compilationCondition: .when([.tvos])),
            ],
            resources: ["MagicMirror/Assets.xcassets"],
            dependencies: [
                .package(product: "MMClientCommon"),
                .package(product: "Collections"),
                .package(product: "KeyCodes"),
                .package(product: "Opus"),
                .package(product: "TPCircularBuffer"),
            ]
        )
    ]
)
