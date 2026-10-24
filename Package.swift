// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Vaani",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vaani", targets: ["Vaani"]),
        .executable(name: "VaaniCLI", targets: ["VaaniCLI"]),
        .library(name: "VaaniCore", targets: ["VaaniCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.5"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "VaaniCore", dependencies: [
            .product(name: "WhisperKit", package: "argmax-oss-swift"),
            .product(name: "FluidAudio", package: "FluidAudio")
        ]),
        .executableTarget(
            name: "Vaani",
            dependencies: ["VaaniCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(name: "VaaniCLI", dependencies: ["VaaniCore"]),
        .testTarget(name: "VaaniCoreTests", dependencies: ["VaaniCore", "Vaani"])
    ],
    swiftLanguageModes: [.v6]
)
