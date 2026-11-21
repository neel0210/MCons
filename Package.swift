// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MCons",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MCons",
            path: "MCons",
            exclude: [
                "Resources",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
