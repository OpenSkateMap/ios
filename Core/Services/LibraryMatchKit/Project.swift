import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "LibraryMatchKit",
    dependencies: [
        .project(target: "SQLiteKit", path: "../../Foundation/SQLiteKit"),
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .external(name: "FactoryKit"),
        .external(name: "SQLiteData"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
