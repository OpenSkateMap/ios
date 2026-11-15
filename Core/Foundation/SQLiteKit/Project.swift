import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "SQLiteKit",
    dependencies: [
        .external(name: "SQLiteData"),
        .external(name: "Dependencies"),
        .external(name: "FactoryKit"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
