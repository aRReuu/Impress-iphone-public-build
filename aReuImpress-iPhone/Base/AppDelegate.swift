//
//  AppDelegate.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 12/3/22.
//  不忘初心,永远也要记得当初为什么要写这个App

import UIKit
import Security


@main
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        // Retired local model and GitHub backup credentials must never survive an upgrade.
        ImRetiredCredentialCleanup.eraseLegacyBackupToken()
        for key in ["kIsAutoGenerateEnabled", "kAutoGenerateIntervalHours", "kLastAutoGenerateFetchDate",
                    "kSystemPrompt", "kSystemPromptMigrated"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // Apply a previously confirmed recovery only before WCDB opens.
        do { try ImpressV3BackupCoordinator.applyPendingAtColdLaunch() }
        catch {
            UserDefaults.standard.set(
                "恢复未完成：" + error.localizedDescription,
                forKey: ImpressV3BackupCoordinator.failureKey)
        }
        // V3 alone handles notification routing; no retired reminder policy.
        ImpressV3NotificationCoordinator.shared.installDelegate()
        return true
    }

    // MARK: UISceneSession Lifecycle
    @available(iOS 13.0, *)
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration
    {
        let sceneConfiguration = UISceneConfiguration(name: "Default Configuration",
                                                      sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = SceneDelegate.self
        return sceneConfiguration
    }
}

/// Only this retired application's own GitHub-backup Keychain item is targeted.
/// It does not touch iCloud, Obsidian permissions or any third-party login.
private enum ImRetiredCredentialCleanup {
    static func eraseLegacyBackupToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.impress.github.token",
            kSecAttrAccount as String: "github_token"
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            NSLog("Legacy backup credential cleanup returned OSStatus %d", status)
        }
    }
}
