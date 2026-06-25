// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalPaste",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LocalPaste", targets: ["LocalPaste"])
    ],
    targets: [
        .executableTarget(
            name: "LocalPaste",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LocalPasteTests",
            dependencies: ["LocalPaste"],
            path: "Tests/LocalPasteTests"
        ),
    ]
)
