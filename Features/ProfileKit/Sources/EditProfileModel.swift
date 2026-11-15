import FactoryKit
import Foundation
import Observation
import PeopleKit
import PhotoUploadKit
import UIKit

@MainActor
@Observable
final class EditProfileModel {

    // MARK: Static Properties

    static let bioLimit = 160

    private static let usernamePattern = /^[A-Za-z0-9_]{5,24}$/
    /// `AvatarEditorView`'s 96 pt at 3x.
    private static let avatarPreviewSide: CGFloat = 288

    // MARK: Computed Properties

    var hasChanges: Bool {
        if case .replaced = draft.avatar {
            return true
        }
        return !ProfileUpdate(from: original, to: draft).isEmpty
    }

    var usernameProblem: String? {
        if let usernameUnavailable {
            return usernameUnavailable
        }
        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, (try? Self.usernamePattern.wholeMatch(in: username)) == nil else {
            return nil
        }
        return ProfileKitStrings.EditProfile.Username.invalid
    }

    var canSave: Bool {
        hasChanges && !isSaving && !isPreparingAvatar && usernameProblem == nil
            && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.bio.count <= Self.bioLimit
    }

    var hasAvatar: Bool {
        switch draft.avatar {
        case .unchanged: original.avatar != nil
        case .removed: false
        case .replaced: true
        }
    }

    // MARK: Properties

    let original: PublicProfile
    var draft: ProfileDraft {
        didSet {
            if draft.username != oldValue.username {
                usernameUnavailable = nil
            }
        }
    }

    private(set) var isSaving = false
    private(set) var isPreparingAvatar = false
    private(set) var usernameUnavailable: String?
    private(set) var avatarPreview: UIImage?

    @ObservationIgnored @Injected(\.profileSession) private var profileSession

    // MARK: Lifecycle

    init(profile: PublicProfile) {
        original = profile
        draft = ProfileDraft(profile)
    }

    // MARK: Functions

    func setAvatar(_ imageData: Data) async throws {
        isPreparingAvatar = true
        defer { isPreparingAvatar = false }
        let prepared = try await profileSession.prepareAvatar(imageData)
        avatarPreview = await prepared.preview(maxPixelSide: Self.avatarPreviewSide)
        draft.avatar = .replaced(prepared)
    }

    func removeAvatar() {
        draft.avatar = original.avatar == nil ? .unchanged : .removed
        avatarPreview = nil
    }

    func save() async throws -> PublicProfile? {
        isSaving = true
        defer { isSaving = false }
        do {
            return try await profileSession.save(draft, over: original)
        } catch PeopleAPIError.usernameUnavailable {
            usernameUnavailable = ProfileKitStrings.EditProfile.Username.unavailable
            return nil
        }
    }
}
