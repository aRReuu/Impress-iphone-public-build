//
//  SceneDelegate.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 12/3/22.
//

import UIKit
import IQKeyboardManagerSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow?
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions)
    {
        guard let _ = (scene as? UIWindowScene) else { return }
//        launchDelay()
        // connectionOptions can carry a cold-start tap before the system
        // notification delegate receives its callback.
        if ImpressV3ReviewEnvironment.pilotEnabled,
           let response = connectionOptions.notificationResponse,
           ImpressV3NotificationCoordinator.isReviewTap(
                actionIdentifier: response.actionIdentifier,
                requestIdentifier: response.notification.request.identifier) {
            ImpressV3NotificationRouteInbox.shared.enqueueReview()
        }
        if let response = connectionOptions.notificationResponse,
           ImpressCalibrationReminderCoordinator.isCalibrationTap(response) {
            ImpressCalibrationNotificationRouteInbox.shared.enqueue()
        }
        // Open only V3; the abandoned impressdata.db is not migrated,
        // opened, cleared or recreated as part of the live startup path.
        do { _ = try ImpressV3ReviewEnvironment.repository() }
        catch { showDatabaseUnavailable(); return }
        initRootVC()
        // Silent V3 backup check: no file picker or cloud permission prompt.
        Task(priority: .utility) {
            await ImpressV3BackupCoordinator.shared.backupIfNeeded()
        }
        ImpressV3NotificationRouteInbox.shared.deliverIfPossible(
            in: window?.rootViewController)
        ImpressCalibrationNotificationRouteInbox.shared.deliverIfPossible(
            in: window?.rootViewController)
        ImpressCalibrationReminderCoordinator.shared.requestReconciliation()
        initKeyboard()
    }
    
    @available(iOS 13.0, *)
    func sceneDidDisconnect(_ scene: UIScene)
    {
        // Do not close WCDB while async operations may still be executing.
        // The thread-safe database handle pool owns its connection lifetime.
    }

    @available(iOS 13.0, *)
    func sceneDidEnterBackground(_ scene: UIScene) {
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
        // Best-effort only: iOS may suspend this work.
        Task(priority: .utility) {
            await ImpressV3BackupCoordinator.shared.backupIfNeeded()
        }
    }
    
    @available(iOS 13.0, *)
    func sceneWillEnterForeground(_ scene: UIScene) {}
    
    @available(iOS 13.0, *)
    func sceneDidBecomeActive(_ scene: UIScene)
    {
        ImpressV3NotificationRouteInbox.shared.deliverIfPossible(
            in: window?.rootViewController)
        ImpressCalibrationNotificationRouteInbox.shared.deliverIfPossible(
            in: window?.rootViewController)
        ImpressV3NotificationCoordinator.shared.requestReconciliation()
        ImpressCalibrationReminderCoordinator.shared.requestReconciliation()
    }
}


// MARK: - initSetting
extension SceneDelegate
{
    func initRootVC()
    {
        let tabBarVC = ImTabBarViewController()
        window?.rootViewController = tabBarVC
        window?.backgroundColor = bgColor
        window?.makeKeyAndVisible()
    }
    
    private func showDatabaseUnavailable() {
        let unavailableVC = UIViewController()
        unavailableVC.view.backgroundColor = .systemBackground
        let message = UILabel()
        message.text = "数据库初始化失败，请重新启动应用后重试。"
        message.numberOfLines = 0
        message.textAlignment = .center
        message.textColor = .label
        message.translatesAutoresizingMaskIntoConstraints = false
        unavailableVC.view.addSubview(message)
        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: unavailableVC.view.leadingAnchor, constant: 24),
            message.trailingAnchor.constraint(equalTo: unavailableVC.view.trailingAnchor, constant: -24),
            message.centerYAnchor.constraint(equalTo: unavailableVC.view.centerYAnchor)
        ])
        window?.rootViewController = unavailableVC
        window?.makeKeyAndVisible()
    }

    /// 初始化键盘配置
    private func initKeyboard()
    {
        let keyboard = IQKeyboardManager.shared
        keyboard.enable = true
        keyboard.enableAutoToolbar = false
        keyboard.shouldResignOnTouchOutside = true
        keyboard.overrideKeyboardAppearance = true
        // 添加全局配置，确保不会被局部设置覆盖
        keyboard.layoutIfNeededOnUpdate = false
        keyboard.keyboardDistanceFromTextField = defaultSpacing
    }


}
