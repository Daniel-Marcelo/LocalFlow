// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "LocalFlow",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // whisper.cpp v1.7.2 — the last tag that ships a SwiftPM manifest with
        // Metal enabled. Fetched into Vendor/ by scripts/fetch-whisper.sh
        // (a local path dependency is required because the whisper manifest
        // uses unsafeFlags, which SwiftPM forbids in remote dependencies).
        .package(path: "Vendor/whisper.cpp")
    ],
    targets: [
        .target(
            name: "LocalFlowCore",
            dependencies: [
                .product(name: "whisper", package: "whisper.cpp")
            ],
            path: "Sources/LocalFlowCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "LocalFlow",
            dependencies: ["LocalFlowCore"],
            path: "Sources/LocalFlowApp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LocalFlowTests",
            dependencies: ["LocalFlowCore"],
            path: "Tests/LocalFlowTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
