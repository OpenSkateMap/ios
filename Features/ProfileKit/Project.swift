import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "ProfileKit",
    dependencies: [
        .project(target: "AccountKit", path: "../../Core/Services/AccountKit"),
        .project(target: "AppLinkKit", path: "../../Core/Foundation/AppLinkKit"),
        .project(target: "PeopleKit", path: "../../Core/Services/PeopleKit"),
        .project(target: "PhotoUploadKit", path: "../../Core/Services/PhotoUploadKit"),
        .project(target: "ImageKit", path: "../../Core/Services/ImageKit"),
        .project(target: "TipJarKit", path: "../../Core/Services/TipJarKit"),
        .project(target: "NotificationsKit", path: "../../Core/Services/NotificationsKit"),
        .project(target: "AnalyticsKit", path: "../../Core/Services/AnalyticsKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .project(target: "SQLiteKit", path: "../../Core/Foundation/SQLiteKit"),
        .external(name: "FactoryKit"),
        .external(name: "PinLayout"),
        .external(name: "SPConfetti"),
        .external(name: "SQLiteData"),
        .external(name: "IdentifiedCollections"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "PeopleKit", path: "../../Core/Services/PeopleKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .project(target: "AccountKit", path: "../../Core/Services/AccountKit"),
        .project(target: "PhotoUploadKit", path: "../../Core/Services/PhotoUploadKit"),
        .project(target: "SQLiteKit", path: "../../Core/Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Core/Models/SpotModelKit"),
        .external(name: "CustomDump"),
        .external(name: "SnapshotTesting"),
        .external(name: "SQLiteData"),
    ],
)
