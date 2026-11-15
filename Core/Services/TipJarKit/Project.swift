import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "TipJarKit",
    dependencies: [
        .external(name: "FactoryKit"),
        .external(name: "RevenueCat"),
    ],
)
