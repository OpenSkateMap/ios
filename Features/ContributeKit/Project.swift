import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "ContributeKit",
    dependencies: [
        .project(target: "AccountKit", path: "../../Core/Services/AccountKit"),
        .project(target: "AppLinkKit", path: "../../Core/Foundation/AppLinkKit"),
        .project(target: "ContributionsKit", path: "../../Core/Services/ContributionsKit"),
        .project(target: "PhotoUploadKit", path: "../../Core/Services/PhotoUploadKit"),
        .project(target: "CollectionsKit", path: "../../Core/Services/CollectionsKit"),
        .project(target: "ReviewKit", path: "../../Core/Services/ReviewKit"),
        .project(target: "SpotModelKit", path: "../../Core/Models/SpotModelKit"),
        .project(target: "ImageKit", path: "../../Core/Services/ImageKit"),
        .project(target: "LocationKit", path: "../../Core/Services/LocationKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .project(target: "SQLiteKit", path: "../../Core/Foundation/SQLiteKit"),
        .external(name: "FactoryKit"),
        .external(name: "PinLayout"),
        .external(name: "SQLiteData"),
        .external(name: "IdentifiedCollections"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "CollectionsKit", path: "../../Core/Services/CollectionsKit"),
        .project(target: "ContributionsKit", path: "../../Core/Services/ContributionsKit"),
        .project(target: "PhotoUploadKit", path: "../../Core/Services/PhotoUploadKit"),
        .project(target: "SpotsKit", path: "../../Core/Services/SpotsKit"),
        .project(target: "ImageKit", path: "../../Core/Services/ImageKit"),
        .project(target: "SQLiteKit", path: "../../Core/Foundation/SQLiteKit"),
        .external(name: "CustomDump"),
        .external(name: "SnapshotTesting"),
    ],
)
