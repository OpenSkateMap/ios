import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "SignInKit",
    dependencies: [
        .project(target: "AccountKit", path: "../../Core/Services/AccountKit"),
        .project(target: "AppLinkKit", path: "../../Core/Foundation/AppLinkKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .external(name: "FactoryKit"),
        .external(name: "PinLayout"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .project(target: "AccountKit", path: "../../Core/Services/AccountKit"),
        .external(name: "FactoryKit"),
        .external(name: "SnapshotTesting"),
    ],
)
