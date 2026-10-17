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
        let cardVC: UIViewController = ImpressV3ReviewEnvironment.pilotEnabled
            ? ImpressV3ReviewViewController()
            : ImCardViewController()
        let cardNav = ImNavigationViewController(rootViewController: cardVC)
        cardNav.tabBarItem.title = "闪卡"
        cardNav.tabBarItem.image = UIImage(systemName: "square.stack.3d.up")
        cardNav.tabBarItem.selectedImage = UIImage(systemName: "square.stack.3d.up.fill")
        
        let noteVC = ImpressNoteListTableViewController()
        let noteNav = ImNavigationViewController(rootViewController: noteVC)
        noteNav.tabBarItem.title = "笔记"
        noteNav.tabBarItem.image = UIImage(systemName: "doc.text")
        noteNav.tabBarItem.selectedImage = UIImage(systemName: "doc.text.fill")

        self.viewControllers = [cardNav, noteNav]
        // Leave the tab bar material to UIKit. Manual barTintColor
        // suppresses the platform's modern floating navigation treatment.
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .secondaryLabel
        if #available(iOS 26.0, *) {
            // The two-tab learning workflow must not jump as notes scroll.
            tabBarMinimizeBehavior = .never
        }
    }
}
