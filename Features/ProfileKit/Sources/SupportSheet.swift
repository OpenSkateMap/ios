import ComponentKit
import FactoryKit
import TipJarKit
import UIKit

enum SupportSheet {

    static func make(tips: [Tip], onTipped: @escaping () -> Void) -> OptionSheetViewController {
        let choice = TipChoiceView(tips: tips)
        let tipJar = Container.shared.tipJarManager()
        let sheet = OptionSheetViewController(
            title: ProfileKitStrings.Support.sheetTitle,
            message: ProfileKitStrings.Support.message,
            content: choice,
            tint: nil,
            confirmTitle: confirmTitle(for: choice.selected),
            failureTitle: ProfileKitStrings.Support.failed,
        ) { [choice] in
            switch try await tipJar.buy(choice.selected.id) {
            case .paid:
                UINotificationFeedbackGenerator(view: choice).notificationOccurred(.success)
                onTipped()

            case .cancelled:
                throw CancellationError()

            case .pending:
                Task {
                    await ToastView().show(.icon(
                        icon: UIImage(systemName: "hourglass") ?? UIImage(),
                        title: ProfileKitStrings.Support.Pending.title,
                        subtitle: ProfileKitStrings.Support.Pending.message,
                    ))
                }
            }
        }
        choice.onChange = { [weak sheet] tip in sheet?.setConfirmTitle(confirmTitle(for: tip)) }
        return sheet
    }

    private static func confirmTitle(for tip: Tip) -> String {
        ProfileKitStrings.Support.confirm(tip.price)
    }
}
