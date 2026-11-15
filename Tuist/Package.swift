// swift-tools-version: 6.2
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    // Shared runtime state (Factory's container, IssueReporting) must exist once per process, so these link as frameworks.
    productTypes: [
        "FactoryKit": .framework,
        "CustomDump": .framework,
        "IssueReporting": .framework,
        "XCTestDynamicOverlay": .framework,
    ],
    baseSettings: .settings(
        base: [
            "ENABLE_MODULE_VERIFIER": "NO",
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
            "SWIFT_EMIT_LOC_STRINGS": "NO",
            "EXCLUDED_ARCHS[sdk=iphonesimulator*]": "x86_64",
        ],
        configurations: [.debug(name: "Debug"), .release(name: "Release")],
    ),
)
#endif

let package = Package(
    name: "OpenSkateMap",
    dependencies: [
        .package(url: "https://github.com/layoutBox/PinLayout", from: "1.10.6"),

        .package(url: "https://github.com/hmlongco/Factory", from: "3.5.0"),

        // Minor-pinned: the generator in .mise/tasks/ios/generate-api is pinned to 1.14.1.
        .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "1.13.1")),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", .upToNextMinor(from: "1.3.2")),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.8.0"),

        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),

        .package(url: "https://github.com/Aeastr/SwiftMacros", revision: "a603ec87d17cf6dd7d9d0c1a4289784ca6cae63e"),

        .package(url: "https://github.com/kean/Nuke", from: "13.2.0"),

        .package(url: "https://github.com/RevenueCat/purchases-ios", from: "5.96.0"),
        .package(url: "https://github.com/ivanvorobei/SPConfetti", from: "1.4.2"),
        .package(url: "https://github.com/buzzkit-dev/buzzkit-ios", from: "1.2.0"),
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.92.0"),

        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
        .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.0.6"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.6"),
    ],
)
