// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoEditor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VideoEditorApp", targets: ["VideoEditorApp"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "FeatureShell", targets: ["FeatureShell"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "Domain",
            dependencies: [],
            path: "Sources/Domain"
        ),
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "Sources/DesignSystem"
        ),
        .target(
            name: "Infrastructure",
            dependencies: [
                "Domain",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/Infrastructure"
        ),
        .target(
            name: "FeatureShell",
            dependencies: [
                "Domain",
                "DesignSystem"
            ],
            path: "Sources/FeatureShell"
        ),
        .executableTarget(
            name: "VideoEditorApp",
            dependencies: [
                "Domain",
                "DesignSystem",
                "FeatureShell",
                "Infrastructure",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/VideoEditorApp"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "FeatureShellTests",
            dependencies: [
                "FeatureShell",
                "Domain"
            ],
            path: "Tests/FeatureShellTests"
        ),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: [
                "Infrastructure",
                "Domain"
            ],
            path: "Tests/InfrastructureTests"
        )
    ]
)
