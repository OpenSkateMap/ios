import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "OpenSkateMap",
    // No automatic schemes: one named OpenSkateMap would make the workspace's `xcodebuild -scheme OpenSkateMap` ambiguous.
    options: projectOptions(),
    settings: .settings(
        base: projectSettings,
        configurations: [
            debugConfiguration(xcconfig: "../xcconfigs/Debug.xcconfig"),
            releaseConfiguration(xcconfig: "../xcconfigs/Release.xcconfig"),
        ],
    ),
    targets: [
        .target(
            name: "OpenSkateMap",
            destinations: [.iPhone],
            product: .app,
            bundleId: "$(BUNDLE_ID)",
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "$(BUNDLE_DISPLAY_NAME)",
                // Releases set both from the tag (`ios:release`); the xcconfig holds the defaults for other builds.
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "ITSAppUsesNonExemptEncryption": false,
                "NSLocationWhenInUseUsageDescription": "OpenSkateMap shows skate spots near you and centers the map on your location.",
                "NSCameraUsageDescription": "OpenSkateMap uses the camera to take photos of the spots you add.",
                "UILaunchScreen": [:],
                // Without it Core Animation caps display links at 60 Hz on iPhone; the globe flights ask for 120.
                "CADisableMinimumFrameDurationOnPhone": true,
                // Continued-processing uploads a person starts (`BackgroundTime.application`); each run adds a suffix.
                "BGTaskSchedulerPermittedIdentifiers": ["$(BUNDLE_ID).upload.*"],
                // Opens the app from Speedflight's install page (`ios:speedflight`); links themselves are universal links.
                "CFBundleURLTypes": [
                    ["CFBundleURLName": "$(BUNDLE_ID)", "CFBundleURLSchemes": ["openskatemap"]]
                ],
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [
                            [
                                "UISceneConfigurationName": "Default Configuration",
                                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate",
                            ]
                        ]
                    ],
                ],
            ]),
            buildableFolders: ["Sources", "Resources"],
            entitlements: .dictionary([
                "com.apple.developer.applesignin": ["Default"],
                "com.apple.developer.associated-domains": ["applinks:openskatemap.app"],
                "aps-environment": "$(APS_ENVIRONMENT)",
            ]),
            dependencies: [
                .project(target: "AccountKit", path: "../Core/Services/AccountKit"),
                .project(target: "SignInKit", path: "../Features/SignInKit"),
                .project(target: "OnboardingKit", path: "../Features/OnboardingKit"),
                .project(target: "ProfileKit", path: "../Features/ProfileKit"),
                .project(target: "TipJarKit", path: "../Core/Services/TipJarKit"),
                .project(target: "NotificationsKit", path: "../Core/Services/NotificationsKit"),
                .project(target: "AnalyticsKit", path: "../Core/Services/AnalyticsKit"),
                .project(target: "SpotsMapKit", path: "../Features/SpotsMapKit"),
                .project(target: "SpotDetailKit", path: "../Features/SpotDetailKit"),
                .project(target: "ContributeKit", path: "../Features/ContributeKit"),
                .project(target: "CollectionDetailKit", path: "../Features/CollectionDetailKit"),
                .project(target: "CollectionsKit", path: "../Core/Services/CollectionsKit"),
                .project(target: "SpotsKit", path: "../Core/Services/SpotsKit"),
                .project(target: "ContributionsKit", path: "../Core/Services/ContributionsKit"),
                .project(target: "ReviewKit", path: "../Core/Services/ReviewKit"),
                .project(target: "PeopleKit", path: "../Core/Services/PeopleKit"),
                .project(target: "ImageKit", path: "../Core/Services/ImageKit"),
                .project(target: "SQLiteKit", path: "../Core/Foundation/SQLiteKit"),
                .project(target: "SpotModelKit", path: "../Core/Models/SpotModelKit"),
                .project(target: "APIClientKit", path: "../Core/Foundation/APIClientKit"),
                .project(target: "AppLinkKit", path: "../Core/Foundation/AppLinkKit"),
                .project(target: "ComponentKit", path: "../Core/UI/ComponentKit"),
                .external(name: "FactoryKit"),
                .external(name: "PinLayout"),
            ],
            settings: .settings(
                base: swift6Settings.merging(mainActorIsolation),
                defaultSettings: .recommended(excluding: ["ASSETCATALOG_COMPILER_APPICON_NAME"]),
            ),
        )
    ],
    resourceSynthesizers: resourceSynthesizers,
)
