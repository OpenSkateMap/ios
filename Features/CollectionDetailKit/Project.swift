import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "CollectionDetailKit",
    dependencies: [
        .project(target: "AppLinkKit", path: "../../Core/Foundation/AppLinkKit"),
        .project(target: "SpotModelKit", path: "../../Core/Models/SpotModelKit"),
        .project(target: "CollectionsKit", path: "../../Core/Services/CollectionsKit"),
        .project(target: "PhotoUploadKit", path: "../../Core/Services/PhotoUploadKit"),
        .project(target: "SpotsKit", path: "../../Core/Services/SpotsKit"),
        .project(target: "ImageKit", path: "../../Core/Services/ImageKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .external(name: "FactoryKit"),
        .external(name: "PinLayout"),
        .external(name: "SQLiteData"),
        .external(name: "IdentifiedCollections"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "SQLiteKit", path: "../../Core/Foundation/SQLiteKit"),
        .project(target: "AccountKit", path: "../../Core/Services/AccountKit"),
        .external(name: "CustomDump"),
        .external(name: "SnapshotTesting"),
    ],
)
