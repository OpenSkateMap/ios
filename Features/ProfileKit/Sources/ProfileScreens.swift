import PeopleKit
public import UIKit

public enum ProfileScreens {
    public static func publicProfile(userID: String) -> UIViewController {
        let navigation = UINavigationController(rootViewController: PublicProfileViewController(userID: userID))
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        return navigation
    }

    public static func reportSpot(id: String) -> UIViewController {
        ReportViewController.inNavigation(target: .spot(id: id))
    }
}
