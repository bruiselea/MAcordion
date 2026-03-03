// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MAcordion",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MAcordion",
            path: "AcOrDiOn",
            exclude: [
                "Info.plist",
                "MAcordion.entitlements",
                "Resources/lid_angle_stream.py"
            ],
            resources: [
                .copy("Resources/how_to_play.png")
            ]
        )
    ]
)
