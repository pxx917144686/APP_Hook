import Darwin.POSIX
import PackageDescription

let theosPath: String = .init(cString: getenv("HOME")) + "/theos"
let minFirmware: String = "15.0"

let swiftFlags: [String] = [
    "-I\(theosPath)/vendor/include",
    "-I\(theosPath)/include",
    "-target", "arm64-apple-ios\(minFirmware)",
    "-sdk", "\(theosPath)/sdks/iPhoneOS15.0.sdk",
    "-resource-dir", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift"
]

let package: Package = .init(
    name: "SatellaJailed++",
    platforms: [.iOS(minFirmware)],
    products: [
        .library(
            name: "SatellaJailed++",
            targets: ["SatellaJailed++"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SatellaJailed++",
            dependencies: [],
            path: "."
        )
    ]
)
