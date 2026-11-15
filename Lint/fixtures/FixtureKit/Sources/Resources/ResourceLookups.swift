import UIKit

enum ResourceLookups {
    static func byName() {
        // expect: generated_resource_accessors
        _ = UIImage(named: "poster")
        // expect: generated_resource_accessors
        _ = Bundle.module.url(forResource: "Clip", withExtension: "mp4")
        // expect: generated_resource_accessors
        _ = UIFont(name: "Mona Sans", size: 17)
        // expect: generated_resource_accessors
        _ = Bundle.main.path(forResource: "Data", ofType: "json")
    }

    static func generated() {
        // Generated accessors and system symbols stay silent.
        _ = UIImage(systemName: "map")
        _ = FixtureAsset.poster.image
        _ = FixtureFiles.clip.url
    }
}
