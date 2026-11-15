import UIKit

enum NewCollectionAlert {
    static func make(onCreate: @escaping (String) -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: CollectionDetailKitStrings.NewCollection.title,
            message: CollectionDetailKitStrings.NewCollection.message,
            preferredStyle: .alert,
        )
        let create = UIAlertAction(title: CollectionDetailKitStrings.NewCollection.create, style: .default) { [weak alert] _ in
            let name = Self.name(alert?.textFields?.first?.text)
            if !name.isEmpty {
                onCreate(name)
            }
        }
        create.isEnabled = false
        alert.addTextField { [weak create] field in
            field.placeholder = CollectionDetailKitStrings.NewCollection.name
            field.autocapitalizationType = .words
            field.addAction(UIAction { [weak field] _ in
                create?.isEnabled = !Self.name(field?.text).isEmpty
            }, for: .editingChanged)
        }
        alert.addAction(UIAlertAction(title: CollectionDetailKitStrings.Alert.cancel, style: .cancel))
        alert.addAction(create)
        return alert
    }

    private static func name(_ text: String?) -> String {
        text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
