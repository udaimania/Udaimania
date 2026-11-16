// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CaptureCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "CaptureCore", targets: ["CaptureCore"])],
    targets: [.target(name: "CaptureCore"), .testTarget(name: "CaptureCoreTests", dependencies: ["CaptureCore"])]
)
