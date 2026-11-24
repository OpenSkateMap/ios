public enum ClipPreparationError: Error, Equatable, Sendable {
    /// The window, cut to the video's length, is shorter than `ClipPreparer.durations`.
    case tooShort
    /// The window is longer than `ClipPreparer.durations`.
    case tooLong
    /// The file has no video track to read.
    case unreadable
    /// The encoder stopped without saying why.
    case encoding
}
