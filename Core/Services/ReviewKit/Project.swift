import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "ReviewKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .external(name: "FactoryKit"),
        .external(name: "OpenAPIRuntime"),
        .external(name: "SQLiteData"),
        .external(name: "IdentifiedCollections"),
    ],
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump"),
        .external(name: "HTTPTypes"),
    ],
)
