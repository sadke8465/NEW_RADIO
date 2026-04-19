// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NewRadio",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NewRadio",
            path: "Sources"
        )
    ]
)
