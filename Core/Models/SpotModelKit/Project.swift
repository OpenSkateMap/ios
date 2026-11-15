import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "SpotModelKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .external(name: "SQLiteData"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump"),
        .external(name: "GRDB"),
    ],
)
