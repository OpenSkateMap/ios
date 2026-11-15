import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "SpotsKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .external(name: "FactoryKit"),
        .external(name: "OpenAPIRuntime"),
        .external(name: "SQLiteData"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump"),
        .external(name: "Clocks"),
    ],
)
