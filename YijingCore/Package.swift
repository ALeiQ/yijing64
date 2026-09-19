// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "YijingCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "YijingCore", targets: ["YijingCore"]),
    ],
    targets: [
        .target(name: "YijingCore"),
        .testTarget(name: "YijingCoreTests", dependencies: ["YijingCore"]),
    ]
)