// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MAcordion",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MAcordion", targets: ["MAcordion"]),
        .executable(name: "MAcordionBreath", targets: ["MAcordionBreath"]),
        .executable(name: "MAcordionShisha", targets: ["MAcordionShisha"]),
    ],
    targets: [
        // Shared library — all audio, input, models, view models, views and
        // bellows sources live here. Both executables import this module.
        .target(
            name: "MAcordionCore",
            path: "AcOrDiOn",
            exclude: [
                "Info.plist",
                "MAcordion.entitlements",
                "Resources"
            ]
        ),
        // Classic MAcordion — bellows driven by the MacBook lid hinge sensor.
        .executableTarget(
            name: "MAcordion",
            dependencies: ["MAcordionCore"],
            path: "MAcordionApp"
        ),
        // MAcordion Breath — bellows driven by microphone amplitude (melodica style).
        .executableTarget(
            name: "MAcordionBreath",
            dependencies: ["MAcordionCore"],
            path: "MAcordionBreath"
        ),
        // MAcordion Shisha — bellows driven by the USB-C-to-Shisha pressure sensor.
        .executableTarget(
            name: "MAcordionShisha",
            dependencies: ["MAcordionCore"],
            path: "MAcordionShisha"
        )
    ]
)
