// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Calendr",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Calendr",
            path: "Sources/Calendr",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CalendrTests",
            dependencies: ["Calendr"],
            path: "Tests/CalendrTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
