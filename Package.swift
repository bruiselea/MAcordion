// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MAcordion",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MAcordion", targets: ["MAcordion"]),
    ],
    targets: [
        // Shared library — audio, hinge input, models, view models, and views.
        .target(
            name: "MAcordionCore",
            path: "AcOrDiOn",
            exclude: [
                "Info.plist",
                "MAcordion.entitlements",
                "Resources"
            ]
        ),
        // MAcordion — bellows driven by the MacBook lid hinge sensor.
        .executableTarget(
            name: "MAcordion",
            dependencies: ["MAcordionCore"],
            path: "MAcordionApp"
        )
    ]
)
