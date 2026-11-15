import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "SpotsMapKit",
    dependencies: [
        .project(target: "SpotsKit", path: "../../Core/Services/SpotsKit"),
        .project(target: "SpotModelKit", path: "../../Core/Models/SpotModelKit"),
        .project(target: "ImageKit", path: "../../Core/Services/ImageKit"),
        .project(target: "LocationKit", path: "../../Core/Services/LocationKit"),
        .project(target: "NotificationsKit", path: "../../Core/Services/NotificationsKit"),
        .project(target: "AnalyticsKit", path: "../../Core/Services/AnalyticsKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .project(target: "SQLiteKit", path: "../../Core/Foundation/SQLiteKit"),
        .external(name: "FactoryKit"),
        .external(name: "PinLayout"),
        .external(name: "SQLiteData"),
        .external(name: "SwiftMacros"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "SpotModelKit", path: "../../Core/Models/SpotModelKit"),
        .external(name: "CustomDump"),
        .external(name: "SnapshotTesting"),
    ],
)
