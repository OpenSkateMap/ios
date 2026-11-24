public import APIClientKit

extension SpotKind {
    public init(_ kind: Components.Schemas.SpotKind) {
        switch kind {
        case .street: self = .street
        case .park: self = .park
        case .diy: self = .diy
        case .plaza: self = .plaza
        }
    }
}

extension Components.Schemas.SpotKind {
    public init(_ kind: SpotKind) {
        switch kind {
        case .street: self = .street
        case .park: self = .park
        case .diy: self = .diy
        case .plaza: self = .plaza
        }
    }
}

extension SpotCondition {
    public init(_ condition: Components.Schemas.SpotCondition) {
        switch condition {
        case .skateable: self = .skateable
        case .knobbed: self = .knobbed
        case .demolished: self = .demolished
        case .busty: self = .busty
        }
    }
}

extension Components.Schemas.SpotCondition {
    public init(_ condition: SpotCondition) {
        switch condition {
        case .skateable: self = .skateable
        case .knobbed: self = .knobbed
        case .demolished: self = .demolished
        case .busty: self = .busty
        }
    }
}

extension SubmissionStatus {
    public init(_ status: Components.Schemas.SubmissionStatus) {
        switch status {
        case .pending: self = .pending
        case .approved: self = .approved
        case .rejected: self = .rejected
        }
    }
}

extension VideoProvider {
    public init(_ provider: Components.Schemas.VideoProvider) {
        switch provider {
        case .youtube: self = .youtube
        case .instagram: self = .instagram
        }
    }
}

extension SpotClip {
    public init(_ clip: Components.Schemas.SpotPhotoClip) {
        self.init(key: clip.key, width: clip.width, height: clip.height, durationMs: clip.durationMs)
    }
}
