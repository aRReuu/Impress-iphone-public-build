import UIKit

extension UIViewController {
    var sliderController: ImSliderViewController? {
        var parentVC = self.parent
        while parentVC != nil {
            if let sliderVC = parentVC as? ImSliderViewController {
                return sliderVC
            }
            parentVC = parentVC?.parent
        }
        
        if let sliderVC = self.presentingViewController as? ImSliderViewController {
            return sliderVC
        }
        
        if let window = UIApplication.shared.windows.first {
            if let rootVC = window.rootViewController as? ImSliderViewController {
                return rootVC
            }
        }
        
        return nil
    }
}


class ImSliderViewController: UIViewController, UIGestureRecognizerDelegate {

    private var mainViewController: UIViewController!
    private var menuViewController: UIViewController!

    private var isMenuOpen = false
    private var menuWidth: CGFloat = 300
    private var panGesture: UIPanGestureRecognizer!

    private lazy var backdropView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isHidden = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
        view.addGestureRecognizer(tapGesture)
        return view
    }()

    convenience init(mainViewController: UIViewController, menuViewController: UIViewController) {
        self.init()
        self.mainViewController = mainViewController
        self.menuViewController = menuViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupGestures()
    }

    private func setupViews() {
        addChild(mainViewController)
        view.addSubview(mainViewController.view)
        mainViewController.didMove(toParent: self)
        mainViewController.view.frame = view.bounds

        view.addSubview(backdropView)
        backdropView.frame = view.bounds
        backdropView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addChild(menuViewController)
        view.addSubview(menuViewController.view)
        menuViewController.didMove(toParent: self)
        menuViewController.view.frame = CGRect(x: -menuWidth, y: 0, width: menuWidth, height: view.bounds.height)
        menuViewController.view.autoresizingMask = [.flexibleHeight]
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handleBackdropTap() {
        toggleMenu()
    }

    func toggleMenu() {
        isMenuOpen ? closeMenu() : openMenu()
    }

    func openMenu() {
        if let navVC = menuViewController as? UINavigationController,
           let chatListVC = navVC.topViewController as? ImPollingChatListViewController {
            chatListVC.fetchChats()
        }
        
        isMenuOpen = true
        backdropView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.mainViewController.view.frame.origin.x = self.menuWidth
            self.menuViewController.view.frame.origin.x = 0
            self.backdropView.backgroundColor = semiTransparentBlack
        })
    }

    func closeMenu() {
        isMenuOpen = false
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.mainViewController.view.frame.origin.x = 0
            self.menuViewController.view.frame.origin.x = -self.menuWidth
            self.backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        }) { _ in
            self.backdropView.isHidden = true
        }
    }

    @objc private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        
        let currentMainX = mainViewController.view.frame.origin.x
        let newMainX = currentMainX + translation.x
        
        if newMainX >= 0 && newMainX <= menuWidth {
            mainViewController.view.frame.origin.x = newMainX
            menuViewController.view.frame.origin.x = newMainX - menuWidth

            let progress = newMainX / menuWidth
            backdropView.backgroundColor = UIColor.black.withAlphaComponent(progress * 0.5)
            backdropView.isHidden = false
        }

        recognizer.setTranslation(.zero, in: view)

        if recognizer.state == .ended {
            let velocity = recognizer.velocity(in: view)
            if velocity.x > 500 {
                openMenu()
            } else if velocity.x < -500 {
                closeMenu()
            } else if mainViewController.view.frame.origin.x > menuWidth / 2 {
                openMenu()
            } else {
                closeMenu()
            }
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let tabBarVC = mainViewController as? ImTabBarViewController else {
            return false
        }
        
        // The chat VC is on the second tab, index 1.
        if tabBarVC.selectedIndex == 1 {
            if let navVC = tabBarVC.selectedViewController as? UINavigationController {
                // Only allow pan gesture to begin if we are at the root view controller of the navigation stack
                return navVC.viewControllers.count == 1
            }
        }
        
        return false
    }
}
