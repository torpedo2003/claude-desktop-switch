// swift-tools-version: 6.0
import PackageDescription

// SwitchCore and SwitchStorage build on every platform. The app, its macOS backend and their tests are macOS only.
var products: [Product] = [.library(name: "SwitchCore", targets: ["SwitchCore"])]
var targets: [Target] = [
    .target(name: "SwitchCore", resources: [.copy("Localizations")]),
    .systemLibrary(name: "CWinSQLite"),
    .target(name: "SwitchStorage", dependencies: [
        "SwitchCore", .target(name: "CWinSQLite", condition: .when(platforms: [.windows])),
    ]),
    .testTarget(name: "SwitchCoreTests", dependencies: [
        "SwitchCore", "SwitchStorage", .target(name: "CWinSQLite", condition: .when(platforms: [.windows])),
    ]),
]

#if os(macOS)
products += [
    .executable(name: "ClaudeSwitch", targets: ["ClaudeSwitch"]),
    .executable(name: "switch-inspect", targets: ["SwitchInspect"]),
]
targets += [
    .target(name: "SwitchMac", dependencies: ["SwitchCore", "SwitchStorage"]),
    .executableTarget(name: "ClaudeSwitch", dependencies: ["SwitchCore", "SwitchStorage", "SwitchMac"]),
    .executableTarget(name: "SwitchInspect", dependencies: ["SwitchCore", "SwitchStorage", "SwitchMac"]),
    .testTarget(name: "SwitchMacTests", dependencies: ["SwitchMac", "SwitchCore", "SwitchStorage"]),
    // Renders the README images from demo data; skipped unless CLAUDE_SWITCH_SCREENSHOTS is set.
    .testTarget(name: "ScreenshotTests", dependencies: ["ClaudeSwitch", "SwitchCore"]),
]
#endif

let package = Package(
    name: "ClaudeDesktopSwitch",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets,
    swiftLanguageModes: [.v5]
)
