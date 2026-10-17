//
//  ImNavigationViewController.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 12/3/22.
//

import UIKit

class ImNavigationViewController: UINavigationController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        navigationBarSetting()
        largeSetting()
    }
    
    private func largeSetting()
    {
        let bar = navigationBar
        let item = navigationItem
        if #available(iOS 11.0, *) {
            bar.prefersLargeTitles = true
            item.largeTitleDisplayMode = .always
        }
        bar.tintColor = funBtnColor
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: titleColor,.backgroundColor: bgColor]
        bar.titleTextAttributes = attributes
        bar.largeTitleTextAttributes = attributes
    }
    
    
    private func navigationBarSetting()
    {
        let img = UIImage()
        navigationBar.isTranslucent = true
        navigationBar.setBackgroundImage(img, for: .default)
        navigationBar.shadowImage = img
    }
    
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool)
    {
        if(children.count > 0) {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}
