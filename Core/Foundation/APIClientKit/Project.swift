import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "APIClientKit",
    dependencies: [
        .external(name: "OpenAPIRuntime"),
        .external(name: "OpenAPIURLSession"),
        .external(name: "HTTPTypes"),
        .external(name: "FactoryKit"),
    ],
    // Generated code keeps unused `public import`s we can't edit, so warnings stay warnings even in CI.
    additionalBaseSettings: ["SWIFT_TREAT_WARNINGS_AS_ERRORS": "NO"],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
