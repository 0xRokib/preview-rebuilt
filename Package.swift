// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PreviewRebuilt",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PreviewRebuilt", targets: ["PreviewRebuilt"])],
    targets: [
        .target(name: "PreviewCore"),
        .executableTarget(name: "PreviewRebuilt", dependencies: ["PreviewCore"]),
        .executableTarget(name: "PreviewSmoke", dependencies: ["PreviewCore"]),
        .testTarget(name: "PreviewCoreTests", dependencies: ["PreviewCore"])
    ]
)
