// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StickySpaces",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "StickySpacesShared", targets: ["StickySpacesShared"]),
        .library(name: "StickySpacesApp", targets: ["StickySpacesApp"]),
        .library(name: "StickySpacesClient", targets: ["StickySpacesClient"]),
        .library(name: "StickySpacesCapture", targets: ["StickySpacesCapture"]),
        .executable(name: "stickyspaces", targets: ["StickySpacesCLI"]),
        .executable(name: "stickyspaces-ui-e2e", targets: ["StickySpacesUIE2E"]),
        .executable(name: "stickyspaces-ui-recorder", targets: ["StickySpacesUIRecorder"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main")
    ],
    targets: [
        .target(
            name: "StickySpacesShared"
        ),
        .target(
            name: "StickySpacesApp",
            dependencies: ["StickySpacesShared"]
        ),
        .target(
            name: "StickySpacesClient",
            dependencies: ["StickySpacesShared"]
        ),
        .target(
            name: "StickySpacesCapture"
        ),
        .executableTarget(
            name: "StickySpacesCLI",
            dependencies: ["StickySpacesApp", "StickySpacesClient", "StickySpacesShared"]
        ),
        .executableTarget(
            name: "StickySpacesUIRecorder",
            dependencies: ["StickySpacesCapture"]
        ),
        .executableTarget(
            name: "StickySpacesUIE2E",
            dependencies: ["StickySpacesApp", "StickySpacesShared"]
        ),
        .testTarget(
            name: "StickySpacesTests",
            dependencies: [
                "StickySpacesApp",
                "StickySpacesClient",
                "StickySpacesCLI",
                "StickySpacesCapture",
                "StickySpacesUIRecorder",
                "StickySpacesShared",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
