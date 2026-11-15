import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "PeopleKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .project(target: "PhotoUploadKit", path: "../PhotoUploadKit"),
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .external(name: "FactoryKit"),
        .external(name: "OpenAPIRuntime"),
        .external(name: "SQLiteData"),
    ],
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "PhotoUploadKit", path: "../PhotoUploadKit"),
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .external(name: "CustomDump"),
        .external(name: "HTTPTypes"),
        .external(name: "SQLiteData"),
    ],
)
