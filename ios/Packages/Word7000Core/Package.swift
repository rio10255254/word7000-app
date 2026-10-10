// swift-tools-version: 5.10
// The learning engine, word data and parsers, with no UI. It builds and tests
// on Linux too, so the rules that decide what a learner sees can be checked
// without a simulator.
import PackageDescription

let package = Package(
    name: "Word7000Core",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Word7000Core", targets: ["Word7000Core"]),
    ],
    targets: [
        .target(name: "Word7000Core"),
        .testTarget(name: "Word7000CoreTests", dependencies: ["Word7000Core"]),
    ]
)
