import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "NotificationsKit",
    dependencies: [
        .external(name: "FactoryKit"),
        .external(name: "BuzzKit"),
    ],
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
