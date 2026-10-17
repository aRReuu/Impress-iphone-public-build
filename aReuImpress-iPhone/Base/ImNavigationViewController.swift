import UIKit

/// Use system-owned navigation chrome (including iOS 26/27 Liquid Glass).
/// No transparent-background hacks: UIKit chooses materials, contrast and spacing.
class ImNavigationViewController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.prefersLargeTitles = true
        navigationBar.tintColor = .systemBlue
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if !children.isEmpty {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}
