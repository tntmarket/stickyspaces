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
        .library(name: "VideoCaptureCore", targets: ["VideoCaptureCore"]),
        .executable(name: "stickyspaces", targets: ["StickySpacesCLI"])
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
            name: "VideoCaptureCore",
            dependencies: ["StickySpacesShared"]
        ),
        .executableTarget(
            name: "StickySpacesCLI",
            dependencies: ["StickySpacesApp", "StickySpacesShared"]
        ),
        .testTarget(
            name: "StickySpacesTests",
            dependencies: [
                "StickySpacesApp",
                "StickySpacesCLI",
                "VideoCaptureCore",
                "StickySpacesShared",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests"
        )
    ]
)
