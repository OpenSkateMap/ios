import AccountKit
import ComponentKit
import FactoryKit
import Foundation
import SpotModelKit
import UIKit

/// Near You's Add Photos: the library, who took each, then an edit adding them after the spot's own; ✕ sends nothing.
@MainActor
final class AddPhotosFlow {

    // MARK: Properties

    private let spot: SpotIndex
    private let model: NewSpotModel
    private weak var presenter: UIViewController?
    private let onFinish: () -> Void
    private var picker: PhotoPicker?
    private var review: PhotoCreditReview?
    private var watching: Task<Void, Never>?

    @Injected(\.authSession) private var authSession

    // MARK: Lifecycle

    init(spot: SpotIndex, presenter: UIViewController, onFinish: @escaping () -> Void) {
        self.spot = spot
        self.presenter = presenter
        self.onFinish = onFinish
        model = NewSpotModel(editing: SpotEditTarget(
            spotID: spot.id,
            title: spot.title,
            about: "",
            kind: spot.kind,
            obstacles: spot.obstacles,
            condition: spot.condition,
            latitude: spot.latitude,
            longitude: spot.longitude,
            address: nil,
            photos: nil,
        ))
        picker = PhotoPicker(
            presenter: presenter,
            limit: { [weak self] in self?.model.form.photosLeft ?? 0 },
            onStart: { [weak self] kinds, _ in self?.begin(kinds.count) ?? { _, _ in } },
        )
    }

    isolated deinit {
        watching?.cancel()
    }

    // MARK: Functions

    func start() {
        picker?.pickPhotos()
    }

    private func begin(_ count: Int) -> PhotoPicker.Receiver {
        let ids = model.beginPhotos(count)
        if let presenter, !ids.isEmpty {
            let review = PhotoCreditReview.present(for: ids, model: model, tint: nil, from: presenter)
            review.onDone = { [weak self] in
                Task { await self?.send() }
            }
            self.review = review
            watchPhotos()
        }
        return { [weak self] index, pick in
            guard let self, index < ids.count else {
                return
            }
            if case .photo(let data) = pick {
                model.fillPhoto(ids[index], with: data)
            } else {
                model.fillPhoto(ids[index], with: nil)
            }
        }
    }

    /// The review shows each photo as it finishes preparing.
    private func watchPhotos() {
        watching?.cancel()
        watching = Task { [weak self] in
            let states = Observations { [weak self] in self?.model.form.photos.map { $0.added?.state != .preparing } ?? [] }
            for await _ in states {
                self?.review?.refresh()
            }
        }
    }

    private func send() async {
        watching?.cancel()
        let dropped = await model.settlePhotos()
        guard !model.form.photos.isEmpty else {
            ToastView.showFailure(
                ContributeKitStrings.Contribute.AddPhotos.failed,
                subtitle: ContributeKitStrings.Contribute.AddPhotos.unreadable,
            )
            onFinish()
            return
        }
        switch await model.submit() {
        case .saved, .approved:
            if let view = presenter?.view {
                UINotificationFeedbackGenerator(view: view).notificationOccurred(.success)
            }
            let title = authSession.isAdmin
                ? ContributeKitStrings.Contribute.AddPhotos.added
                : ContributeKitStrings.Contribute.AddPhotos.sent
            let subtitle = dropped > 0 ? ContributeKitStrings.Contribute.AddPhotos.someLeftOut : spot.title
            Task { await ToastView().show(.icon(predefinedIcon: .success, title: title, subtitle: subtitle)) }

        case .busy, .failed, .cardChanged:
            ToastView.showFailure(ContributeKitStrings.Contribute.AddPhotos.failed)
        }
        onFinish()
    }
}
