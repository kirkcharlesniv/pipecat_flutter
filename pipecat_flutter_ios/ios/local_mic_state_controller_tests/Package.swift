// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "local_mic_state_controller_tests",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "LocalMicStateControllerSupport",
            targets: ["LocalMicStateControllerSupport"]
        )
    ],
    targets: [
        .target(
            name: "LocalMicStateControllerSupport",
            path: "Sources/LocalMicStateControllerSupport"
        ),
        .testTarget(
            name: "LocalMicStateControllerSupportTests",
            dependencies: ["LocalMicStateControllerSupport"]
        ),
    ]
)
