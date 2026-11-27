public import FactoryKit
import SQLiteKit

extension Container {
    public var photoLibrary: Factory<PhotoLibrary> {
        self { .live }
            .singleton
            .onPreview { .preview }
    }

    public var imageClassifier: Factory<ImageClassifier> {
        self { .live }
            .singleton
            .onPreview { .preview }
    }

    public var libraryMatchEngine: Factory<LibraryMatchEngine> {
        self {
            LibraryMatchEngine(database: self.database(), library: self.photoLibrary(), classifier: self.imageClassifier())
        }
        .singleton
    }

    /// Not account-scoped: its phase follows the device's photo access. The account-end handler's
    /// `LibraryMatchEngine.reset()` cancels the scan and clears the matches.
    @MainActor
    public var libraryMatchSession: Factory<LibraryMatchSession> {
        self { LibraryMatchSession(engine: self.libraryMatchEngine(), library: self.photoLibrary()) }.singleton
    }
}
