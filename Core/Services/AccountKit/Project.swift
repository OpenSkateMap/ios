import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "AccountKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .external(name: "FactoryKit"),
        .external(name: "OpenAPIRuntime"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump"),
        .external(name: "HTTPTypes"),
    ],
)
