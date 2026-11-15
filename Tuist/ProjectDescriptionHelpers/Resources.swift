import ProjectDescription

/// The Settings bundle's Acknowledgements ship the same languages.
public let appLanguages = ["en", "ar", "de", "es", "fr", "hi", "it", "ja", "pl", "pt", "ru", "tr", "uk", "zh-Hans", "zh-Hant"]

public func projectOptions() -> Project.Options {
    .options(automaticSchemesOptions: .disabled, defaultKnownRegions: appLanguages + ["Base"], developmentRegion: "en")
}

public let resourceSynthesizers: [ResourceSynthesizer] = .default + [.files(extensions: ["mp4", "mov", "json"])]
