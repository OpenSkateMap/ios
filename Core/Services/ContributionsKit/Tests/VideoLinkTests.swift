import CustomDump
import Foundation
import SpotModelKit
import Testing
@testable import ContributionsKit

@Suite(.timeLimit(.minutes(1)))
struct VideoLinkTests {
    @Test
    func `every YouTube form of one clip reads as the same video`() throws {
        for string in [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtube.com/watch?v=dQw4w9WgXcQ&si=tracking&feature=share",
            "http://m.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ?si=abc&t=42",
            "https://www.youtube.com/shorts/dQw4w9WgXcQ",
            "https://www.youtube.com/live/dQw4w9WgXcQ",
            "https://www.youtube.com/embed/dQw4w9WgXcQ",
            "  https://www.youtube.com/watch?v=dQw4w9WgXcQ  ",
        ] {
            let link = try #require(VideoLink(string: string), "\(string)")
            expectNoDifference(link.provider, .youtube)
            expectNoDifference(link.externalID, "dQw4w9WgXcQ")
            expectNoDifference(link.url.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
            expectNoDifference(link.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        }
    }

    @Test
    func `Instagram posts, reels and IGTV read without the account`() throws {
        for (string, url) in [
            ("https://www.instagram.com/reel/C1aB2cD3eF4/?igsh=xyz", "https://www.instagram.com/reel/C1aB2cD3eF4/"),
            ("https://instagram.com/reels/C1aB2cD3eF4", "https://www.instagram.com/reel/C1aB2cD3eF4/"),
            ("https://www.instagram.com/tv/C1aB2cD3eF4/", "https://www.instagram.com/reel/C1aB2cD3eF4/"),
            ("https://www.instagram.com/someskater/reel/C1aB2cD3eF4/", "https://www.instagram.com/reel/C1aB2cD3eF4/"),
            ("https://www.instagram.com/p/C1aB2cD3eF4/", "https://www.instagram.com/p/C1aB2cD3eF4/"),
        ] {
            let link = try #require(VideoLink(string: string), "\(string)")
            expectNoDifference(link.provider, .instagram)
            expectNoDifference(link.url.absoluteString, url)
            #expect(link.thumbnailURL == nil)
        }
    }

    @Test
    func `anything else is not a video link`() {
        for string in [
            "",
            "not a link",
            "ftp://youtu.be/dQw4w9WgXcQ",
            "https://vimeo.com/123456",
            "https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ",
            "https://www.youtube.com/@channel",
            "https://www.youtube.com/watch?v=short",
            "https://www.youtube.com/watch?v=dQw4w9WgXcé",
            "https://www.instagram.com/someskater/",
            "https://www.instagram.com/a/b/reel/C1aB2cD3eF4/",
            "javascript:alert(1)",
        ] {
            #expect(VideoLink(string: string) == nil, "\(string)")
        }
    }
}
