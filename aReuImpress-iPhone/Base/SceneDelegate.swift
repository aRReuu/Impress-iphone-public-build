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
        // Open and verify tables before the first card VC starts querying.
        guard initDB() else {
            showDatabaseUnavailable()
            return
        }
        initRootVC()
        ImpressV3NotificationRouteInbox.shared.deliverIfPossible(
            in: window?.rootViewController)
        // Backups may present UIKit; the root controller must exist first.
        dbShare.checkBackupReminder(from: window?.rootViewController ?? UIViewController()) { error in
            if let error = error {
                zcLog("Backup check failed: \(error.localizedDescription)")
            }
        }
        initNotificationSetting()
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
        // Post a notification for any interested parts of the app to save their state.
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }
    
    @available(iOS 13.0, *)
    func sceneWillEnterForeground(_ scene: UIScene) {}
    
    @available(iOS 13.0, *)
    func sceneDidBecomeActive(_ scene: UIScene)
    {
        // 3秒后重新计算并重置iCon角标数据
        if ImpressV3ReviewEnvironment.pilotEnabled {
            ImpressV3NotificationRouteInbox.shared.deliverIfPossible(
                in: window?.rootViewController)
            ImpressV3NotificationCoordinator.shared.requestReconciliation()
        } else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + ImAnimationConfig.generateDelay) {
                notificationShare.rescheduleDailyReminder()
            }
        }
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
    
    /// Initialize all required legacy tables; do not proceed on failure.
    @discardableResult
    private func initDB() -> Bool {
        let manager = FileManager.default
        do {
            if !manager.fileExists(atPath: documentPath) {
                try manager.createDirectory(atPath: documentPath,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            }
        } catch {
            zcLog("Create database directory failed: \(error.localizedDescription)")
            return false
        }
        return dbShare.createAllDB()
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

    /// 关闭数据库
    private func closeDB()
    {
        dbShare.closeDB()
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

    /// 初始化推送权限
    private func initNotificationSetting()
    {
        // Never show a system permission prompt on V3 cold launch.
        // Users may explicitly enable reminders from the V3 screen.
        if !ImpressV3ReviewEnvironment.pilotEnabled {
            notificationShare.requestAuthorization()
        }
    }
    
    private func launchDelay()
    {
        #if !DEBUG
        Thread.sleep(forTimeInterval: ImAnimationConfig.generateDelay)
        #endif
    }
    
}
