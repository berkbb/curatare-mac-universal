// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Curatare",
    defaultLocalization: "tr",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "CuratareCore", targets: ["CuratareCore"]),
        .executable(name: "Curatare", targets: ["Curatare"])
    ],
    targets: [
        .target(
            name: "CuratareCore",
            path: "Sources/CuratareCore"
        ),
        .executableTarget(
            name: "Curatare",
            dependencies: ["CuratareCore"],
            path: "Sources/Curatare"
        ),
        .testTarget(
            name: "CuratareCoreTests",
            dependencies: ["CuratareCore"],
            path: "Tests/CuratareCoreTests"
        ),
        .testTarget(
            name: "CuratareAppTests",
            dependencies: ["Curatare", "CuratareCore"],
            path: "Tests/CuratareAppTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
