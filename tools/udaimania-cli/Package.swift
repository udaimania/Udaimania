// swift-tools-version:5.9
import PackageDescription

// Phase 1 of the Udaimania CLI: a standalone, read-only executable.
//
// It deliberately has no dependencies. SQLite comes from the system SDK, and
// argument parsing is hand-rolled, so this builds with `swift build` alone and
// can later be folded into Udaimania.app as an Xcode target without dragging any
// package resolution along with it.
let package = Package(
  name: "udaimania-cli",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(
      name: "udaimania",
      path: "Sources/udaimania"
    )
  ]
)
