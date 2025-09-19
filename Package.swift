// swift-tools-version: 6.1
import Darwin.POSIX
import PackageDescription

let theosPath: String = .init(cString: getenv("HOME")) + "/theos"
let minFirmware: String = "15.0"

let swiftFlags: [String] = [
    "-I\(theosPath)/vendor/include",
    "-I\(theosPath)/include",
    "-F\(theosPath)/vendor/lib",
    "-F\(theosPath)/lib",
    "-target", "arm64-apple-ios\(minFirmware)",
    "-sdk", "\(theosPath)/sdks/iPhoneOS15.0.sdk",
    "-resource-dir", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift",
    "-Xlinker", "-undefined",
    "-Xlinker", "dynamic_lookup",
    "-Xlinker", "-flat_namespace"
]

let package: Package = .init(
    name: "APP_hook",
    platforms: [.iOS(minFirmware)],
    products: [
        .library(
            name: "APP_hook",
            type: .dynamic,
            targets: ["APP_hook"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "APP_hook",
            dependencies: [],
            path: ".",
            exclude: [
                "Package.swift",
                "Makefile",
                "Jinx",
                ".build",
                ".theos"
            ],
            sources: [
                "Core",
                "Models",
                "Sk1",
                "Sk2",
                "UI",
                "Tweak.swift"
            ],
            swiftSettings: [
                .unsafeFlags(swiftFlags),
                .enableExperimentalFeature("StrictConcurrency")
            ],
            linkerSettings: [
                .unsafeFlags(["-undefined", "dynamic_lookup", "-flat_namespace"])
            ]
        )
    ]
)
