import ProjectDescription

public let deploymentTargets = DeploymentTargets.iOS("26.0")

public let projectSettings: SettingsDictionary = [
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "NO",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "STRING_CATALOG_GENERATE_SYMBOLS": "NO",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "EXCLUDED_ARCHS[sdk=iphonesimulator*]": "x86_64",
]

public let debugBuildPerformanceSettings: SettingsDictionary = [
    "CLANG_ENABLE_MODULE_DEBUGGING": "NO",
    "EAGER_LINKING": "YES",
    "ONLY_ACTIVE_ARCH": "YES",
]

public func debugConfiguration(xcconfig: Path? = nil) -> Configuration {
    .debug(name: "Debug", settings: debugBuildPerformanceSettings, xcconfig: xcconfig)
}

public func releaseConfiguration(xcconfig: Path? = nil) -> Configuration {
    .release(name: "Release", xcconfig: xcconfig)
}

public let swift6Settings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
    "SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT": "YES",
    "SWIFT_UPCOMING_FEATURE_INFER_ISOLATED_CONFORMANCES": "YES",
    "SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT": "YES",
    "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
    "SWIFT_TREAT_WARNINGS_AS_ERRORS": Environment.isCI ? "YES" : "NO",
]

public let staticFrameworkSettings = swift6Settings.merging([
    "MODULE_VERIFIER_SUPPORTED_LANGUAGES": "objective-c objective-c++",
    "MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS": "gnu17 gnu++20",
])

public let mainActorIsolation: SettingsDictionary = [
    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor"
]

/// Snapshots draw dates and text in the test runner's language and region, so every Mac and CI run them in the same one.
public let testActionOptions = TestActionOptions.options(language: "en", region: "GB")
