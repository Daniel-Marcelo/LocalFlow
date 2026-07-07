// swift-tools-version:5.10

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
        .executableTarget(
            name: "LocalFlow",
            dependencies: [
                .product(name: "whisper", package: "whisper.cpp")
            ],
            path: "Sources/LocalFlow"
        ),
        .testTarget(
            name: "LocalFlowTests",
            dependencies: ["LocalFlow"],
            path: "Tests/LocalFlowTests"
        ),
    ]
)
