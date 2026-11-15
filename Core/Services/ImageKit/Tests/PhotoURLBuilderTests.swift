import CustomDump
import Foundation
import Testing
@testable import ImageKit

@Suite(.timeLimit(.minutes(1)))
struct PhotoURLBuilderTests {
    @Test
    func `without an image domain photos don't load`() {
        #expect(PhotoURLBuilder(baseURL: nil).url(for: "photos/a.jpg", size: .pin, scale: 3) == nil)
    }

    @Test
    func `variants are sized at the screen scale and cropped except full screen`() throws {
        let base = try #require(URL(string: "https://images.openskatemap.app"), "A literal URL that doesn't parse")
        let builder = PhotoURLBuilder(baseURL: base)

        expectNoDifference(
            builder.url(for: "photos/a.jpg", size: .pin, scale: 3)?.absoluteString,
            "https://images.openskatemap.app/cdn-cgi/image/width=144,fit=cover,format=auto/photos/a.jpg",
        )
        expectNoDifference(
            builder.url(for: "photos/a.jpg", size: .fullScreen, scale: 2)?.absoluteString,
            "https://images.openskatemap.app/cdn-cgi/image/width=2048,fit=scale-down,format=auto/photos/a.jpg",
        )
    }
}
