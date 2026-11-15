import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "AnalyticsKit",
    dependencies: [
        .external(name: "FactoryKit"),
        .external(name: "PostHog"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
