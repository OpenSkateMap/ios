import ProjectDescription
import ProjectDescriptionHelpers

let project = moduleProject(
    name: "OnboardingKit",
    dependencies: [
        .project(target: "AppLinkKit", path: "../../Core/Foundation/AppLinkKit"),
        .project(target: "ComponentKit", path: "../../Core/UI/ComponentKit"),
        .external(name: "FactoryKit"),
        .external(name: "PinLayout"),
    ],
    mainActorByDefault: true,
    buildableFolders: ["Sources", "Resources"],
    hasTests: true,
    testDependencies: [
        .external(name: "CustomDump")
    ],
)
