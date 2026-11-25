import ComponentKit
import UIKit

/// The sheet's one clip player. The view that asks last gets it (a clip asked for again, as when the viewer opens on
/// the card's clip, keeps playing where it was); it goes as soon as no view shows it.
final class ClipPlayback {

    // MARK: Properties

    private var player: LoopingClipPlayer?
    private let views = NSHashTable<ClipLayerView>.weakObjects()

    // MARK: Functions

    func show(_ url: URL, in view: ClipLayerView) {
        if player?.url != url {
            player?.pause()
            for other in views.allObjects where other !== view {
                other.player = nil
            }
            views.removeAllObjects()
            player = LoopingClipPlayer(url: url)
        }
        views.add(view)
        view.player = player
        player?.play()
    }

    func player(of url: URL) -> LoopingClipPlayer? {
        player?.url == url ? player : nil
    }

    func currentFrame(of url: URL) -> UIImage? {
        guard player?.url == url else {
            return nil
        }
        return views.allObjects.lazy.compactMap(\.currentFrame).first
    }

    func release(_ view: ClipLayerView) {
        view.player = nil
        views.remove(view)
        if views.allObjects.isEmpty {
            player?.pause()
            player = nil
        }
    }
}
