import os
public import PhotosUI
public import UIKit
import UniformTypeIdentifiers

// MARK: - PhotoPicker

public final class PhotoPicker: NSObject {

    // MARK: Types

    /// Takes each picked file by its place in the pick, as it arrives.
    public typealias Receiver = (_ index: Int, _ data: Data?) -> Void

    /// Where a pick came from; a photo taken with the camera here is the person's own.
    public enum Source: Sendable {
        case camera
        case library
        case files
    }

    private enum Delivery {
        case whole((_ files: [Data?]) -> Void)
        case each((_ count: Int, _ source: Source) -> Receiver)
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "photo-picker")

    // MARK: Properties

    private weak var presenter: UIViewController?
    private let limit: () -> Int
    private let delivery: Delivery

    // MARK: Lifecycle

    /// `onPick` gets every file at once, after the last one has loaded.
    public init(presenter: UIViewController, limit: @escaping () -> Int = { 1 }, onPick: @escaping ([Data?]) -> Void) {
        self.presenter = presenter
        self.limit = limit
        delivery = .whole(onPick)
    }

    /// `onStart` hears how many were picked, and from where, once the picker is off screen (so it can present), so
    /// each can show as loading; the receiver it returns gets each file as it arrives (an iCloud original can take seconds).
    public init(presenter: UIViewController,
                limit: @escaping () -> Int,
                onStart: @escaping (_ count: Int, _ source: Source) -> Receiver) {
        self.presenter = presenter
        self.limit = limit
        delivery = .each(onStart)
    }

    // MARK: Static Functions

    private static func load(_ read: () async throws -> Data) async -> Data? {
        do {
            return try await read()
        } catch {
            logger.error("A picked photo couldn't be read: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    @concurrent
    private nonisolated static func read(_ url: URL) async throws -> Data {
        try Data(contentsOf: url)
    }

    @concurrent
    private nonisolated static func jpeg(_ photo: UIImage?) async -> Data? {
        photo?.jpegData(compressionQuality: 0.92)
    }

    // MARK: Functions

    public func actions() -> [UIMenuElement] {
        var actions = [UIMenuElement]()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actions.append(UIAction(
                title: ComponentKitStrings.PhotoPicker.takePhoto,
                image: UIImage(systemName: "camera"),
            ) { [weak self] _ in
                self?.takePhoto()
            })
        }
        actions.append(UIAction(
            title: ComponentKitStrings.PhotoPicker.photoLibrary,
            image: UIImage(systemName: "photo.on.rectangle"),
        ) { [weak self] _ in
            self?.pickPhotos()
        })
        actions.append(UIAction(
            title: ComponentKitStrings.PhotoPicker.chooseFile,
            image: UIImage(systemName: "folder"),
        ) { [weak self] _ in
            self?.chooseFiles()
        })
        return actions
    }

    private func takePhoto() {
        let camera = UIImagePickerController()
        camera.sourceType = .camera
        camera.mediaTypes = [UTType.image.identifier]
        camera.delegate = self
        presenter?.present(camera, animated: true)
    }

    private func pickPhotos() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = limit()
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    private func deliver(_ count: Int, from source: Source, loading load: @escaping (_ index: Int) async -> Data?) {
        guard count > 0 else {
            return
        }
        switch delivery {
        case .whole(let onPick):
            Task {
                var files = [Data?]()
                for index in 0..<count {
                    files.append(await load(index))
                }
                onPick(files)
            }

        case .each(let onStart):
            let receive = onStart(count, source)
            Task {
                for index in 0..<count {
                    receive(index, await load(index))
                }
            }
        }
    }

    private func chooseFiles() {
        // A copy, so the file stays readable after the picker closes without a security scope.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        picker.allowsMultipleSelection = limit() > 1
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }
}

// MARK: PHPickerViewControllerDelegate

extension PhotoPicker: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let providers = results.map(\.itemProvider)
        picker.dismiss(animated: true) {
            self.deliver(providers.count, from: .library) { index in
                await Self.load { try await providers[index].imageData() }
            }
        }
    }
}

// MARK: UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension PhotoPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController,
                                      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let photo = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) {
            self.deliver(1, from: .camera) { _ in await Self.jpeg(photo) }
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: UIDocumentPickerDelegate

extension PhotoPicker: UIDocumentPickerDelegate {
    public func documentPicker(_ picker: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let files = Array(urls.prefix(max(limit(), 0)))
        let deliver = { self.deliver(files.count, from: .files) { index in
            await Self.load { try await Self.read(files[index]) }
        } }
        // It closes itself, and may still be on its way out.
        guard let closing = picker.transitionCoordinator else {
            return deliver()
        }
        closing.animate(alongsideTransition: nil) { _ in deliver() }
    }
}

extension NSItemProvider {
    fileprivate func imageData() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadDataRepresentation(for: .image) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
        }
    }
}
