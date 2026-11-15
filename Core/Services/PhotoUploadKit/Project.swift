import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "PhotoUploadKit",
    dependencies: [
        .project(target: "APIClientKit", path: "../../Foundation/APIClientKit"),
        .project(target: "ImageKit", path: "../ImageKit"),
        .external(name: "FactoryKit"),
        .external(name: "OpenAPIRuntime"),
    ],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
