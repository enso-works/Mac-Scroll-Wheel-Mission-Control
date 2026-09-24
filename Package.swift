// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScrollWheelMissionControl",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ScrollWheelMissionControl",
            path: "Sources/ScrollWheelMissionControl"
        )
    ]
)
