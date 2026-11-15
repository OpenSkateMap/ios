import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "CollectionsKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .project(target: "SpotsKit", path: "../SpotsKit"),
        .project(target: "PhotoUploadKit", path: "../PhotoUploadKit"),
        .external(name: "FactoryKit"),
        .external(name: "OpenAPIRuntime"),
        .external(name: "SQLiteData"),
        .external(name: "IdentifiedCollections"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump"),
        .external(name: "GRDB"),
    ],
)
