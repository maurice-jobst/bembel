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
        // System bzip2 (libbz2 ships in every Apple SDK). DWD publishes the
        // RADOLAN composites bzip2-compressed, and Apple's Compression
        // framework covers zlib/lzfse/lz4/lzma but not bzip2 — this shim is
        // what keeps BEM-F01 free of third-party packages.
        // The modulemap's `link "bz2"` is advisory for a plain target, so the
        // linker flag lives here where it travels to every dependent.
        .target(name: "CBZip2", linkerSettings: [.linkedLibrary("bz2")]),
        .target(name: "BEMBELKit", dependencies: ["CBZip2"], resources: [.process("Resources")]),
        .testTarget(
            name: "BEMBELKitTests",
            dependencies: ["BEMBELKit"],
            resources: [.process("Fixtures")]
        ),
    ]
)
