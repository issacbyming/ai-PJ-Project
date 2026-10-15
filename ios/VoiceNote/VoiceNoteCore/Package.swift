// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceNoteCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VoiceNoteCore", targets: ["VoiceNoteCore"]),
    ],
    targets: [
        .target(name: "VoiceNoteCore"),
        .testTarget(name: "VoiceNoteCoreTests", dependencies: ["VoiceNoteCore"]),
    ]
)
