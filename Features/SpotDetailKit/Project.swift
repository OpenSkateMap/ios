import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "SpotDetailKit",
    dependencies: [
        .project(target: "SpotsKit", path: "../../Core/Services/SpotsKit"),
        .project(target: "ContributionsKit", path: "../../Core/Services/ContributionsKit"),
        .project(target: "CollectionsKit", path: "../../Core/Services/CollectionsKit"),
        .project(target: "SpotModelKit", path: "../../Core/Models/SpotModelKit"),
        .project(target: "ImageKit", path: "../../Core/Services/ImageKit"),
        .project(target: "LocationKit", path: "../../Core/Services/LocationKit"),
        .project(target: "AnalyticsKit", path: "../../Core/Services/AnalyticsKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .project(target: "AppLinkKit", path: "../../Core/Foundation/AppLinkKit"),
        .project(target: "AccountKit", path: "../../Core/Services/AccountKit"),
        .project(target: "SQLiteKit", path: "../../Core/Foundation/SQLiteKit"),
        .external(name: "FactoryKit"),
        .external(name: "PinLayout"),
        .external(name: "SQLiteData"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "ImageKit", path: "../../Core/Services/ImageKit"),
        .project(target: "SpotModelKit", path: "../../Core/Models/SpotModelKit"),
        .external(name: "FactoryKit"),
        .external(name: "Nuke"),
        .external(name: "SnapshotTesting"),
    ],
)
