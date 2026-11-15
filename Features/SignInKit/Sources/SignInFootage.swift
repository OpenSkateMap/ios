import UIKit

/// Romain Batard's footage, in the bundle only when `mise run ios:fetch-assets` fetched it before the build.
struct SignInFootage {

    // MARK: Static Computed Properties

    static var bundled: SignInFootage? {
        // swiftlint:disable generated_resource_accessors - the files may be absent, so no accessor is generated for them
        guard let video = Bundle.module.url(forResource: "SignInLoop", withExtension: "mp4"),
              let posterPath = Bundle.module.path(forResource: "SignInPoster", ofType: "jpg"),
              let poster = UIImage(contentsOfFile: posterPath) else {
            return nil
        }
        // swiftlint:enable generated_resource_accessors
        return SignInFootage(video: video, poster: poster)
    }

    // MARK: Properties

    let video: URL
    let poster: UIImage
}
