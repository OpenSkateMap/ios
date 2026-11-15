import UIKit

// MARK: - ReorderableCollectionViewDelegate

/// Owns the order a `ReorderableCollectionView` shows and makes the copy a person drags.
protocol ReorderableCollectionViewDelegate: AnyObject {
    func collectionView(_ collectionView: ReorderableCollectionView, canMoveItemAt indexPath: IndexPath) -> Bool

    /// A copy of the item to drag, which lays itself out at whatever size it's given.
    func collectionView(_ collectionView: ReorderableCollectionView, liftedViewForItemAt indexPath: IndexPath) -> UIView?

    /// Moves the item in the delegate's data and in the view (a diffable data source applies a snapshot).
    func collectionView(_ collectionView: ReorderableCollectionView, moveItemAt source: IndexPath, to destination: IndexPath)

    func collectionView(_ collectionView: ReorderableCollectionView, didLiftItemAt indexPath: IndexPath)

    /// The finger lifted, or the drag was cancelled, with the item at `indexPath`.
    func collectionView(_ collectionView: ReorderableCollectionView, didEndReorderingItemAt indexPath: IndexPath)
}

extension ReorderableCollectionViewDelegate {
    func collectionView(_: ReorderableCollectionView, canMoveItemAt _: IndexPath) -> Bool {
        true
    }

    func collectionView(_: ReorderableCollectionView, didLiftItemAt _: IndexPath) { }

    func collectionView(_: ReorderableCollectionView, didEndReorderingItemAt _: IndexPath) { }
}
