// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountToThreeKit",
    // macOS ist nur dabei, damit die Tests des Datenmodells ohne Simulator laufen.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CountToThreeKit", targets: ["CountToThreeKit"]),
    ],
    targets: [
        .target(name: "CountToThreeKit"),
        .testTarget(name: "CountToThreeKitTests", dependencies: ["CountToThreeKit"]),
    ]
)
