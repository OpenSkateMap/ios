import AppLinkKit
import CustomDump
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct AppLinkTests {
    @Test
    func `a spot's link is its page on the site and reads back as the spot`() {
        let link = AppLink.spot(id: "0199d3c4-7a51-7b20-9f6e-2b8f0c1d4e5a")

        expectNoDifference(link.url.absoluteString, "https://openskatemap.app/spots/0199d3c4-7a51-7b20-9f6e-2b8f0c1d4e5a")
        expectNoDifference(AppLink(url: link.url), link)
    }

    @Test
    func `a collection's map link reads back as that collection on the map`() throws {
        let link = AppLink.collectionMap(id: "6f1c2d3e-4a5b-4c6d-8e9f-0a1b2c3d4e5f")

        expectNoDifference(
            link.url.absoluteString,
            "https://openskatemap.app/collections/6f1c2d3e-4a5b-4c6d-8e9f-0a1b2c3d4e5f/map",
        )
        expectNoDifference(AppLink(url: link.url), link)
        expectNoDifference(AppLink(url: try #require(URL(string: "https://openskatemap.app/collections/c1/list"))), nil)
    }

    @Test
    func `a collection's link is its page on the site and reads back as the collection`() {
        let link = AppLink.collection(id: "6f1c2d3e-4a5b-4c6d-8e9f-0a1b2c3d4e5f")

        expectNoDifference(link.url.absoluteString, "https://openskatemap.app/collections/6f1c2d3e-4a5b-4c6d-8e9f-0a1b2c3d4e5f")
        expectNoDifference(AppLink(url: link.url), link)
    }

    @Test
    func `a spot link opens however it was written down`() throws {
        let addresses = [
            "https://openskatemap.app/spots/abc/",
            "https://openskatemap.app/spots/abc?utm_source=messages#photos",
            "HTTPS://OpenSkateMap.app/spots/abc",
        ]

        for address in addresses {
            let url = try #require(URL(string: address), "A literal URL that doesn't parse")
            expectNoDifference(AppLink(url: url), .spot(id: "abc"), "\(address)")
        }
    }

    @Test
    func `addresses that aren't the app's open nothing`() throws {
        let addresses = [
            "https://example.com/spots/abc",
            "https://www.openskatemap.app/spots/abc",
            "http://openskatemap.app/spots/abc",
            "https://openskatemap.app/privacy",
            "https://openskatemap.app/spots",
            "https://openskatemap.app/spots/abc/photos",
            "https://openskatemap.app/collections",
            "https://openskatemap.app/lists/abc",
            "https://api.openskatemap.app/spots/abc",
        ]

        for address in addresses {
            let url = try #require(URL(string: address), "A literal URL that doesn't parse")
            #expect(AppLink(url: url) == nil, "\(address)")
        }
    }
}
