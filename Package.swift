// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GongLaoBu",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GongLaoBu", targets: ["GongLaoBu"])
    ],
    targets: [
        .executableTarget(
            name: "GongLaoBu",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("Security")
            ]
        )
    ]
)
