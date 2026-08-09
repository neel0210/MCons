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
                "Resources/Info.plist",
                "Resources/MCons.entitlements",
                "Resources/AppIcon.icns",
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/IconPacks"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
