import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "ImageKit",
    dependencies: [
        .external(name: "FactoryKit"),
        .external(name: "Nuke"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
