// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SoundSource",
    platforms: [.macOS("14.2")],
    targets: [
        .executableTarget(name: "SoundSource", path: "Sources/SoundSource")
    ]
)
