import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "ComponentKit",
    dependencies: [
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .project(target: "ImageKit", path: "../../Services/ImageKit"),
        .external(name: "PinLayout"),
        .external(name: "SwiftMacros"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "SpotModelKit", path: "../../Models/SpotModelKit"),
        .external(name: "CustomDump"),
    ],
)
