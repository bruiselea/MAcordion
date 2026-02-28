// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AcOrDiOn",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AcOrDiOn", targets: ["AcOrDiOn"])
    ],
    targets: [
        .executableTarget(
            name: "AcOrDiOn",
            path: "Sources/AcOrDiOn"
        )
    ]
)
