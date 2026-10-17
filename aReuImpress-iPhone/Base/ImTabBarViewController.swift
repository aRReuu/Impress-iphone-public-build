//
//  ImTabBarViewController.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 12/24/22.
//

import UIKit

class ImTabBarViewController: UITabBarController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        tabBarSetting()
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        // 备份逻辑已迁移到APP冷启动时执行
    }

    private func tabBarSetting()
    {
        let cardVC = ImpressV3ReviewViewController()
        let cardNav = ImNavigationViewController(rootViewController: cardVC)
        cardNav.tabBarItem.title = "闪卡"
        cardNav.tabBarItem.image = UIImage(systemName: "square.stack.3d.up")
        cardNav.tabBarItem.selectedImage = UIImage(systemName: "square.stack.3d.up.fill")
        
        let noteVC = ImpressNoteListTableViewController()
        let noteNav = ImNavigationViewController(rootViewController: noteVC)
        noteNav.tabBarItem.title = "笔记"
        noteNav.tabBarItem.image = UIImage(systemName: "doc.text")
        noteNav.tabBarItem.selectedImage = UIImage(systemName: "doc.text.fill")

        let settingsVC = ImpressV3SettingsHubViewController()
        let settingsNav = ImNavigationViewController(rootViewController: settingsVC)
        settingsNav.tabBarItem.title = "设置"
        settingsNav.tabBarItem.image = UIImage(systemName: "gearshape")
        settingsNav.tabBarItem.selectedImage = UIImage(systemName: "gearshape.fill")

        self.viewControllers = [cardNav, noteNav, settingsNav]
        // Page extends underneath the native floating bar; no fake glass.
        view.backgroundColor = ImpressV3Appearance.page
        ImpressV3Appearance.styleTabBar(tabBar)
        if #available(iOS 26.0, *) {
            // Keep primary navigation stationary while reading or reviewing.
            tabBarMinimizeBehavior = .never
        }
    }
}
