import Foundation
public import SQLiteData

/// The words a spot is found by: its title folded (case, accents, ё as е, й as и) and its Latin spellings, one row per
/// indexed spot. `SpotSyncEngine` writes a spot's row with its index row; deleting the index row deletes it (trigger).
@Table("spot_search")
public struct SpotSearchText: FTS5, Equatable, Sendable {

    // MARK: Static Properties

    private static let romanization: [Character: String] = [
        "а": "a",
        "б": "b",
        "в": "v",
        "г": "g",
        "ґ": "g",
        "д": "d",
        "е": "e",
        "ё": "e",
        "є": "ye",
        "ж": "zh",
        "з": "z",
        "и": "i",
        "і": "i",
        "ї": "yi",
        "й": "y",
        "к": "k",
        "л": "l",
        "м": "m",
        "н": "n",
        "о": "o",
        "п": "p",
        "р": "r",
        "с": "s",
        "т": "t",
        "у": "u",
        "ф": "f",
        "х": "kh",
        "ц": "ts",
        "ч": "ch",
        "ш": "sh",
        "щ": "shch",
        "ъ": "",
        "ы": "y",
        "ь": "",
        "э": "e",
        "ю": "yu",
        "я": "ya",
    ]

    // MARK: Properties

    public let spotID: String
    public var title: String
    public var latin: String

    // MARK: Lifecycle

    public init(spotID: String, title: String) {
        self.spotID = spotID
        self.title = Self.fold(title)
        latin = Self.latinSpellings(of: title)
    }

    // MARK: Static Functions

    /// Text as search compares it: no case, accents or width, so "Ёлки" and "елки" are the same words.
    public static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// The words someone typed, folded the same way as titles.
    public static func words(of query: String) -> [String] {
        fold(query).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// The `MATCH` pattern for typed words: each must start a word of the title or of a Latin spelling, quoted so
    /// nothing typed reads as query syntax.
    public static func pattern(for words: [String]) -> String {
        words.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }.joined(separator: " ")
    }

    /// Replaces the rows of these spots, for a writer of the index.
    public static func replace(for spots: [SpotIndex], _ db: Database) throws {
        guard !spots.isEmpty else {
            return
        }
        try SpotSearchText.where { $0.spotID.in(spots.map(\.id)) }.delete().execute(db)
        try SpotSearchText.insert { spots.map { SpotSearchText(spotID: $0.id, title: $0.title) } }.execute(db)
    }

    /// The system's transliteration and the common one people type ("Новокрестовская": "novokrestovskaa",
    /// "novokrestovskaya"); empty for a title already in Latin letters.
    static func latinSpellings(of title: String) -> String {
        let lowered = title.lowercased()
        let folded = fold(lowered)
        let spellings = [lowered.applyingTransform(.toLatin, reverse: false), romanized(lowered)]
            .compactMap { $0.map(fold) }
            .filter { $0 != folded }
        return NSOrderedSet(array: spellings).array.compactMap { $0 as? String }.joined(separator: " ")
    }

    private static func romanized(_ lowered: String) -> String {
        lowered.reduce(into: "") { result, character in
            result += romanization[character] ?? String(character)
        }
    }
}
