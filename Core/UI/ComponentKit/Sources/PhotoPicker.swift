import os
public import PhotosUI
public import UIKit
import UniformTypeIdentifiers

// MARK: - PhotoPicker

public final class PhotoPicker: NSObject {

    // MARK: Types

    /// Takes each picked file by its place in the pick, as it arrives; nil when it couldn't be read.
    public typealias Receiver = (_ index: Int, _ pick: Pick?) -> Void

    /// What a place in a pick holds, known before its file arrives.
    public enum Kind: Equatable, Sendable {
        case photo
        case video
    }

    public enum Pick: Equatable, Sendable {
        /// The image's bytes as stored.
        case photo(Data)
        /// A copy in the temporary folder that the receiver owns and removes once done; a video is never read into memory.
        case video(URL)
    }

    /// Where a pick came from; a photo taken with the camera here is the person's own.
    public enum Source: Sendable {
        case camera
        case library
        case files
    }

    private enum Delivery {
        case whole((_ files: [Data?]) -> Void)
        case each((_ kinds: [Kind], _ source: Source) -> Receiver)
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "photo-picker")

    // MARK: Properties

    private weak var presenter: UIViewController?
    private let limit: () -> Int
    private let allowsVideos: Bool
    private let delivery: Delivery

    // MARK: Lifecycle

    /// `onPick` gets every file at once, after the last one has loaded.
    public init(presenter: UIViewController, limit: @escaping () -> Int = { 1 }, onPick: @escaping ([Data?]) -> Void) {
        self.presenter = presenter
        self.limit = limit
        allowsVideos = false
        delivery = .whole(onPick)
    }

    /// `onStart` hears what was picked at each place, and from where, once the picker is off screen (so it can present),
    /// so each can show as loading; the receiver it returns gets each file as it arrives (an iCloud original can take
    /// seconds). With `allowsVideos` the library and Files offer videos too; the camera only takes photos.
    public init(presenter: UIViewController,
                limit: @escaping () -> Int,
                allowsVideos: Bool = false,
                onStart: @escaping (_ kinds: [Kind], _ source: Source) -> Receiver) {
        self.presenter = presenter
        self.limit = limit
        self.allowsVideos = allowsVideos
        delivery = .each(onStart)
    }

    // MARK: Static Functions

    private static func load(_ read: () async throws -> Pick) async -> Pick? {
        do {
            return try await read()
        } catch {
            logger.error("A picked file couldn't be read: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    @concurrent
    private nonisolated static func read(_ url: URL) async throws -> Pick {
        try .photo(Data(contentsOf: url))
    }

    @concurrent
    private nonisolated static func jpeg(_ photo: UIImage?) async throws -> Pick {
        guard let data = photo?.jpegData(compressionQuality: 0.92) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return .photo(data)
    }

    private static func isVideo(_ url: URL) -> Bool {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: .movie) ?? false
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

    /// The photo library on its own, for a button that only adds from it.
    public func pickPhotos() {
        var configuration = PHPickerConfiguration()
        configuration.filter = allowsVideos ? .any(of: [.images, .videos]) : .images
        configuration.selectionLimit = limit()
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    private func deliver(_ kinds: [Kind], from source: Source, loading load: @escaping (_ index: Int) async -> Pick?) {
        guard !kinds.isEmpty else {
            return
        }
        switch delivery {
        case .whole(let onPick):
            Task {
                var files = [Data?]()
                for index in kinds.indices {
                    files.append(await load(index)?.photo)
                }
                onPick(files)
            }

        case .each(let onStart):
            let receive = onStart(kinds, source)
            Task {
                for index in kinds.indices {
                    receive(index, await load(index))
                }
            }
        }
    }

    private func chooseFiles() {
        // A copy, so the file stays readable after the picker closes without a security scope.
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: allowsVideos ? [.image, .movie] : [.image],
            asCopy: true,
        )
        picker.allowsMultipleSelection = limit() > 1
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }
}

// MARK: PHPickerViewControllerDelegate

extension PhotoPicker: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let providers = results.map(\.itemProvider)
        let kinds = providers.map { self.allowsVideos && $0.holdsVideo ? Kind.video : .photo }
        picker.dismiss(animated: true) {
            self.deliver(kinds, from: .library) { index in
                await Self.load {
                    switch kinds[index] {
                    case .photo: try await .photo(providers[index].imageData())
                    case .video: try await .video(providers[index].videoCopy())
                    }
                }
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
            self.deliver([.photo], from: .camera) { _ in await Self.load { try await Self.jpeg(photo) } }
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
        let kinds = files.map { self.allowsVideos && Self.isVideo($0) ? Kind.video : .photo }
        let deliver = { self.deliver(kinds, from: .files) { index in
            switch kinds[index] {
            case .photo: await Self.load { try await Self.read(files[index]) }
            // The picker's copy is already the app's own.
            case .video: .video(files[index])
            }
        } }
        // It closes itself, and may still be on its way out.
        guard let closing = picker.transitionCoordinator else {
            return deliver()
        }
        closing.animate(alongsideTransition: nil) { _ in deliver() }
    }
}

extension PhotoPicker.Pick {
    fileprivate var photo: Data? {
        if case .photo(let data) = self {
            data
        } else {
            nil
        }
    }
}

extension NSItemProvider {
    /// A Live Photo carries a movie too, and stays a photo.
    fileprivate var holdsVideo: Bool {
        hasItemConformingToTypeIdentifier(UTType.movie.identifier) && !hasItemConformingToTypeIdentifier(UTType.image.identifier)
    }

    /// The provider's file is removed as its handler returns, so it's copied out there; nothing reads it into memory.
    fileprivate func videoCopy() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadFileRepresentation(for: .movie, openInPlace: false) { file, _, error in
                guard let file else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                    return
                }
                let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(file.pathExtension)")
                do {
                    try FileManager.default.copyItem(at: file, to: copy)
                    continuation.resume(returning: copy)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

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
