import CustomDump
import GRDB
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotModelKit

@Suite(.timeLimit(.minutes(1)))
struct CityNameTests {
    private static let petersburg = City(
        id: "spb",
        slug: "saint-petersburg",
        name: "Saint Petersburg",
        names: [
            "en": "Saint Petersburg",
            "ru": "Санкт-Петербург",
            "de": "Sankt Petersburg",
            "zh-Hans": "圣彼得堡",
            "zh-Hant": "聖彼得堡",
        ],
        countryCode: "RU",
        minLatitude: 59.6,
        minLongitude: 29.4,
        maxLatitude: 60.2,
        maxLongitude: 30.8,
    )

    @Test
    func `a city shows its name in the first of the person's languages it has one in`() {
        let city = Self.petersburg

        expectNoDifference(city.localizedName(preferring: ["ru-RU", "en-US"]), "Санкт-Петербург")
        expectNoDifference(city.localizedName(preferring: ["nl-NL", "de-AT", "ru"]), "Sankt Petersburg")
        expectNoDifference(city.localizedName(preferring: ["en-GB"]), "Saint Petersburg")
    }

    @Test
    func `Chinese goes by script, whatever the region says`() {
        let city = Self.petersburg

        expectNoDifference(city.localizedName(preferring: ["zh-Hans-CN"]), "圣彼得堡")
        expectNoDifference(city.localizedName(preferring: ["zh-Hant-TW"]), "聖彼得堡")
        expectNoDifference(city.localizedName(preferring: ["zh-HK"]), "聖彼得堡")
        expectNoDifference(city.localizedName(preferring: ["zh-SG"]), "圣彼得堡")
    }

    @Test
    func `a city without names, or none in the person's languages, shows its English name`() {
        var city = Self.petersburg
        expectNoDifference(city.localizedName(preferring: ["nl", "sv"]), "Saint Petersburg")

        city.names = [:]
        expectNoDifference(city.localizedName(preferring: ["ru"]), "Saint Petersburg")
    }

    @Test
    func `names survive the database, so a cold start offline shows them`() throws {
        let database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { db in try City.insert { Self.petersburg }.execute(db) }

        let stored = try database.read { db in try City.find("spb").fetchOne(db) }

        expectNoDifference(stored, Self.petersburg)
    }
}
