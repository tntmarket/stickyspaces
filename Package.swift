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
            name: "StickySpacesClient",
            dependencies: ["StickySpacesShared"]
        ),
        .executableTarget(
            name: "StickySpacesCLI",
            dependencies: ["StickySpacesApp", "StickySpacesClient", "StickySpacesShared"]
        ),
        .testTarget(
            name: "StickySpacesTests",
            dependencies: [
                "StickySpacesApp",
                "StickySpacesClient",
                "StickySpacesCLI",
                "StickySpacesShared",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
