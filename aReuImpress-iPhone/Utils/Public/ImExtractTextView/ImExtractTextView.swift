//
//  ImExtractTextView.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 12/10/24.
//

import UIKit

class ImExtractTextView: UITextView, UITextViewDelegate
{
    private var longTap: UILongPressGestureRecognizer?

    /// Markdown渲染器
    private let markdownRenderer = MarkdownKitRenderer()

    /// 文本摘录回调 - 只传递选中文本，业务逻辑完全交给外部处理
    var onTextExtracted: ((String) -> Void)?

    override var text: String! {
        didSet {
//            applyMarkdownStyles()
        }
    }
    
    // MARK: - 菜单控件设置
    deinit {
        if let l = longTap { removeGestureRecognizer(l) }
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        addToggleAndExtractionsLongTap()
        initUISetting()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addToggleAndExtractionsLongTap()
        initUISetting()
    }
    
    open override var canBecomeFirstResponder: Bool { return true }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if  action == #selector(copy(_:)) ||
            action == #selector(extractSpecifiedContent) {
            return true
        }
        return false
    }
    
    
    private func initUISetting() {
        self.font = UIFont.preferredFont(forTextStyle: .body)
        self.textColor = contentColor
        self.textAlignment = .center
        self.textContainerInset = UIEdgeInsets.init(top: textDefaultContainerInset,
                                                    left: textDefaultContainerInset,
                                                    bottom: textDefaultContainerInset,
                                                    right: textDefaultContainerInset)
    }
    
    func textView(_ textView: UITextView,
                  shouldInteractWith URL: URL,
                  in characterRange: NSRange,
                  interaction: UITextItemInteraction) -> Bool {
        let tappedText = (textView.text as NSString).substring(with: characterRange)
        zcLog("clieked: \(tappedText)")
        return false
    }
    
    
    /// 隐藏菜单+选择
    private func hideMenu() {
        UIMenuController.shared.hideMenu()
        resignFirstResponder()
    }
    
    /// 添加长按后显示的子菜单功能
    private func addToggleAndExtractionsLongTap() {
        longTap = UILongPressGestureRecognizer(target: self,
                                               action: #selector(handleLongPress(_:)))
        longTap?.minimumPressDuration = 1.0
        addGestureRecognizer(longTap!)
        
        let menu = UIMenuController.shared
        let extractItem = UIMenuItem(title: imExtractTitle,
                                    action: #selector(extractSpecifiedContent))
        menu.menuItems = [extractItem]
    }
    
    
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            becomeFirstResponder()
            let menu = UIMenuController.shared
            if let range = selectedTextRange {
                let selectedTextRect = firstRect(for: range)
                menu.showMenu(from: self, rect: selectedTextRect)
            } else {
                menu.showMenu(from: self, rect: bounds)
            }
        }
    }
    
    /// 提取选中的内容 - 通过block回调交给外部处理
    @objc private func extractSpecifiedContent() {
        if let textRange = selectedTextRange,
           let text = text(in: textRange) {
            if let callback = onTextExtracted {
                // 新方式：通过block回调传递选中文本
                callback(text)
            } else {
                // 向后兼容：如果没有设置回调，使用原有逻辑
                insertExtractChat(by: text)
            }
            hideMenu()
        }
    }
}



// MARK:  - Markdown渲染
extension ImExtractTextView
{
    private func applyMarkdownStyles()
    {
        guard let text = self.text, !text.isEmpty else { return }
        if let attributedText = markdownRenderer.parseMarkdown(text) {
            self.attributedText = attributedText
        }
    }
}

// MARK: - 保存数据
extension ImExtractTextView {
    func insertExtractChat(by title: String) {
        var e = ImPreChatModel()
        e.question = title
        e.updateTime = Date()
        dbShare.insertToDB(intoTable: ImDBTableType.preChat.description,
                           with: [e]) { (result) in
            if case .failure(let error) = result {
                ImAlertController.warningAlert(error.localizedDescription)
            }
        }
    }
}
