import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "AppLinkKit",
    dependencies: [
        .external(name: "FactoryKit")
    ],
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
