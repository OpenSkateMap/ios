import ProjectDescription

public func moduleProject(name: String,
                          dependencies: [TargetDependency],
                          mainActorByDefault: Bool = false,
                          buildableFolders: [BuildableFolder] = ["Sources"],
                          additionalBaseSettings: SettingsDictionary = [:],
                          hasTests: Bool = false,
                          testDependencies: [TargetDependency] = []) -> Project {
    let bundlePrefix = "com.ertembiyik.openskatemap"

    var moduleBase = staticFrameworkSettings
    if mainActorByDefault {
        moduleBase = moduleBase.merging(mainActorIsolation)
    }
    moduleBase = moduleBase.merging(additionalBaseSettings)

    var targets: [Target] = [
        .target(
            name: name,
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "\(bundlePrefix).\(name)",
            deploymentTargets: deploymentTargets,
            buildableFolders: buildableFolders,
            dependencies: dependencies,
            settings: .settings(base: moduleBase, defaultSettings: .recommended),
        )
    ]

    if hasTests {
        targets.append(
            .target(
                name: "\(name)Tests",
                destinations: .iOS,
                product: .unitTests,
                bundleId: "\(bundlePrefix).\(name)Tests",
                deploymentTargets: deploymentTargets,
                buildableFolders: ["Tests"],
                dependencies: [.target(name: name)] + testDependencies,
                settings: .settings(
                    base: swift6Settings.merging(["ENABLE_TESTING_SEARCH_PATHS": "YES"]),
                    defaultSettings: .recommended,
                ),
            )
        )
    }

    let scheme: Scheme =
        if hasTests {
            .scheme(
                name: name,
                buildAction: .buildAction(targets: ["\(name)", "\(name)Tests"]),
                testAction: .targets(["\(name)Tests"], configuration: "Debug", options: testActionOptions),
            )
        } else {
            .scheme(name: name, buildAction: .buildAction(targets: ["\(name)"]))
        }

    return Project(
        name: name,
        options: projectOptions(),
        settings: .settings(
            base: projectSettings,
            configurations: [debugConfiguration(), releaseConfiguration()],
        ),
        targets: targets,
        schemes: [scheme],
        resourceSynthesizers: resourceSynthesizers,
    )
}
