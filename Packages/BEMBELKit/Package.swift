// swift-tools-version: 6.0
import PackageDescription

// macOS is a supported platform so `swift test` runs natively on any Mac and
// in CI without booting a simulator — there is no Mac app (ADR 0004).
let package = Package(
    name: "BEMBELKit",
    defaultLocalization: "de",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "BEMBELKit", targets: ["BEMBELKit"])
    ],
    targets: [
        .target(name: "BEMBELKit", resources: [.process("Resources")]),
        .testTarget(name: "BEMBELKitTests", dependencies: ["BEMBELKit"]),
    ]
)
