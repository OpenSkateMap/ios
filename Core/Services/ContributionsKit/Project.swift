import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "ContributionsKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .project(target: "PhotoUploadKit", path: "../PhotoUploadKit"),
        .external(name: "FactoryKit"),
        .external(name: "OpenAPIRuntime"),
        .external(name: "SQLiteData"),
    ],
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "PhotoUploadKit", path: "../PhotoUploadKit"),
        .external(name: "CustomDump"),
        .external(name: "HTTPTypes"),
    ],
)
