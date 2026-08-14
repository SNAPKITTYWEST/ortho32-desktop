// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ORTHO32Desktop",
    // Windows 10+ (1809+) — Win32 + Direct2D + ConPTY
    // No macOS target. No AppKit. No Metal.
    platforms: [],
    products: [
        .executable(name: "ORTHO32Desktop", targets: ["ORTHO32Desktop"])
    ],
    dependencies: [
        .package(url: "https://github.com/OpenSwiftUIProject/OpenSwiftUI", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "ORTHO32Desktop",
            dependencies: [
                .product(name: "OpenSwiftUI", package: "OpenSwiftUI"),
                "ORTHOBridge"
            ],
            path: "Sources/ORTHO32Desktop",
            swiftSettings: [
                .define("WINDOWS_11"),
                .define("ORTHO_FABRIC_TARGET")
            ],
            linkerSettings: [
                .linkedLibrary("d2d1"),
                .linkedLibrary("dwrite"),
                .linkedLibrary("dxgi"),
                .linkedLibrary("user32"),
                .linkedLibrary("kernel32")
            ]
        ),
        .target(
            name: "ORTHOBridge",
            path: "Sources/ORTHOBridge",
            swiftSettings: [.define("WINDOWS_11")]
        )
    ]
)
