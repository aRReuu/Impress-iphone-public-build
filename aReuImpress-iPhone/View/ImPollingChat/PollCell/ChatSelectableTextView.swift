import UIKit

/// 轻量级聊天消息专用TextView，只专注于下划线功能
class ChatSelectableTextView: UITextView {

    /// 下划线操作回调
    var onUnderlineOperation: ((UnderlineOperation) -> Void)?

    // 下划线操作类型
    enum UnderlineOperation {
        case add(range: NSRange, text: String)  // 添加下划线
        case remove(underlineId: UUID)          // 移除下划线
    }

    // 当前消息的完整内容（用于计算位置）
    private var fullContent: String = ""
    // 当前消息的下划线信息
    private var underlines: [UnderlineRange] = []

    // 长按手势识别器
    private var longPressGesture: UILongPressGestureRecognizer!

    // 静态菜单项，确保对象稳定性
    private static var underlineMenuItem: UIMenuItem = {
        return UIMenuItem(title: "添加下划线", action: #selector(addUnderlineAction))
    }()
    private static var removeUnderlineMenuItem: UIMenuItem = {
        return UIMenuItem(title: "移除下划线", action: #selector(removeUnderlineAction))
    }()

    // MARK: - Initialization

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // 默认字体,外部进行修改
        font = UIFont.preferredFont(forTextStyle: .body)
        textColor = titleColor
        textAlignment = .left
        textContainerInset = UIEdgeInsets(top: textDefaultContainerInset,
                                         left: textDefaultContainerInset,
                                         bottom: textDefaultContainerInset,
                                         right: textDefaultContainerInset)
        textContainer.lineFragmentPadding = 0
        backgroundColor = .clear

        // 添加长按手势用于显示菜单
        longPressGesture = UILongPressGestureRecognizer(target: self,
                                                        action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)

        // 设置菜单项（参考ImExtractTextView的方式）
        setupMenuItems()

        // 禁用智能引号等格式化
        autocorrectionType = .no
        autocapitalizationType = .none
        smartQuotesType = .no
        smartDashesType = .no

        // 启用用户交互
        isUserInteractionEnabled = true
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
    }

    /// 设置菜单项（使用静态菜单项确保稳定性）
    private func setupMenuItems() {
        let menu = UIMenuController.shared
        // 使用静态菜单项，避免每次创建新对象
        menu.menuItems = [ChatSelectableTextView.underlineMenuItem, ChatSelectableTextView.removeUnderlineMenuItem]
    }

    // MARK: - Menu Actions

    override open var canBecomeFirstResponder: Bool { return true }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(addUnderlineAction), #selector(removeUnderlineAction):
            return true
        case #selector(copy(_:)):
            return super.canPerformAction(action, withSender: sender)
        default:
            return false // 只允许copy、下划线、移除下划线
        }
    }

    @objc private func addUnderlineAction() {
        guard let range = selectedTextRange,
              let selectedText = text(in: range),
              !selectedText.isEmpty else {
            hideMenu()
            return
        }

        // 计算在完整内容中的位置
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = selectedText.utf16.count

        let operation = UnderlineOperation.add(range: NSRange(location: location,
                                                            length: length),
                                             text: selectedText)
        onUnderlineOperation?(operation)

        // 重置选中状态
        selectedTextRange = nil
        hideMenu()
    }

    @objc private func removeUnderlineAction() {
        guard let range = selectedTextRange else {
            hideMenu()
            return
        }

        // 计算位置并查找对应的下划线
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)

        // 查找点击位置对应的下划线
        if let underlineRange = findUnderlineAt(location: location, length: length) {
            let operation = UnderlineOperation.remove(underlineId: underlineRange.id)
            onUnderlineOperation?(operation)
        }

        selectedTextRange = nil
        hideMenu()
    }

    // MARK: - Underline Management

    /// 更新下划线信息并重新渲染
    func updateUnderlines(_ newUnderlines: [UnderlineRange], fullContent: String) {
        self.underlines = newUnderlines
        self.fullContent = fullContent
        renderUnderlines()
    }

    /// 渲染下划线效果 - 兼容纯文本和markdown渲染两种情况
    private func renderUnderlines() {
        guard !fullContent.isEmpty else {
            return // 没有内容，不渲染
        }

        // 获取要修改的富文本
        var attributedText: NSMutableAttributedString

        if let existingAttributedText = self.attributedText {
            // 情况1：已经有attributedText（机器人消息-markdown已渲染）
            attributedText = NSMutableAttributedString(attributedString: existingAttributedText)
        } else {
            // 情况2：没有attributedText（用户消息-纯文本）
            // 需要创建基础的富文本样式，但不影响通过其他方式设置的样式
            attributedText = NSMutableAttributedString(string: self.text ?? fullContent)
            // 设置基础样式，以保持与原有的text设置一致
            let fullRange = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 17), range: fullRange)
            attributedText.addAttribute(.foregroundColor, value: self.textColor ?? .label, range: fullRange)
            // 保留paragraphStyle、对齐等可能已设置的样式
            if let existingStyle = self.attributedText?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                attributedText.addAttribute(.paragraphStyle, value: existingStyle, range: fullRange)
            }
        }

        // 只清除下划线相关的属性，保留其他所有样式
        attributedText.removeAttribute(.underlineStyle, range: NSRange(location: 0, length: attributedText.length))
        attributedText.removeAttribute(.underlineColor, range: NSRange(location: 0, length: attributedText.length))

        // 应用新的下划线
        for underline in underlines {
            guard underline.startIndex + underline.length <= attributedText.length else {
                continue // 跳过无效的下划线
            }

            let range = NSRange(location: underline.startIndex, length: underline.length)

            // 添加下划线样式，同时设置文本颜色为醒目颜色
            attributedText.addAttribute(.underlineStyle,
                                      value: NSUnderlineStyle.single.rawValue,
                                      range: range)
            attributedText.addAttribute(.underlineColor,
                                      value: reviewCellColor,
                                      range: range)
            // 设置下划线文本的字体颜色为醒目颜色
            attributedText.addAttribute(.foregroundColor,
                                      value: reviewCellColor,
                                      range: range)
        }

        self.attributedText = attributedText
    }

    /// 在指定位置查找下划线
    private func findUnderlineAt(location: Int, length: Int) -> UnderlineRange? {
        // 根据位置查找最接近的下划线
        return underlines.first { underline in
            let underlineStart = underline.startIndex
            let underlineEnd = underline.startIndex + underline.length

            // 检查是否点击了下划线区域
            return location >= underlineStart && location <= underlineEnd
        }
    }

    // MARK: - Gesture Handling

    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began && canBecomeFirstResponder {
            let menu = UIMenuController.shared

            // 确保菜单项被正确设置（包含下划线和移除下划线选项）
            menu.menuItems = [ChatSelectableTextView.underlineMenuItem, ChatSelectableTextView.removeUnderlineMenuItem]

            // 只有在成功成为第一响应者后才能显示菜单
            if becomeFirstResponder() {
                // 优先检查是否点击了现有的下划线
                let point = gestureRecognizer.location(in: self)
                let characterIndex = layoutManager.characterIndex(for: point,
                                                                in: textContainer,
                                                                fractionOfDistanceBetweenInsertionPoints: nil)

                // 边界检查：确保字符索引在有效范围内
                if characterIndex >= 0 && characterIndex < (self.text?.utf16.count ?? 0) {
                    if let underline = findUnderlineAt(location: characterIndex, length: 0) {
                        // 点击了下划线，选择对应的范围并显示菜单
                        let startPosition = position(from: beginningOfDocument, offset: underline.startIndex)
                        let endPosition = position(from: beginningOfDocument, offset: underline.startIndex + underline.length)

                        if let textRange = textRange(from: startPosition!, to: endPosition!) {
                            selectedTextRange = textRange
                            let selectedTextRect = firstRect(for: textRange)

                            // 修复崩溃：检查矩形是否有效，避免NaN坐标
                            if selectedTextRect.isNull ||
                               selectedTextRect.origin.x.isNaN ||
                               selectedTextRect.origin.y.isNaN ||
                               selectedTextRect.size.width.isNaN ||
                               selectedTextRect.size.height.isNaN {
                                menu.showMenu(from: self, rect: bounds)
                            } else {
                                menu.showMenu(from: self, rect: selectedTextRect)
                            }
                            return
                        }
                    }
                }

                // 标准处理：参照ImExtractTextView的方式
                if let range = selectedTextRange {
                    let selectedTextRect = firstRect(for: range)

                    // 修复崩溃：检查矩形是否有效，避免NaN坐标
                    if selectedTextRect.isNull ||
                       selectedTextRect.origin.x.isNaN ||
                       selectedTextRect.origin.y.isNaN ||
                       selectedTextRect.size.width.isNaN ||
                       selectedTextRect.size.height.isNaN {
                        // 如果矩形无效，使用整个bounds作为备用
                        menu.showMenu(from: self, rect: bounds)
                    } else {
                        menu.showMenu(from: self, rect: selectedTextRect)
                    }
                } else {
                    // 没有选中内容时，选择点击位置的单词
                    if selectWordAt(point: point) {
                        let selectedTextRect = firstRect(for: selectedTextRange!)

                        // 修复崩溃：检查矩形是否有效，避免NaN坐标
                        if selectedTextRect.isNull ||
                           selectedTextRect.origin.x.isNaN ||
                           selectedTextRect.origin.y.isNaN ||
                           selectedTextRect.size.width.isNaN ||
                           selectedTextRect.size.height.isNaN {
                            menu.showMenu(from: self, rect: bounds)
                        } else {
                            menu.showMenu(from: self, rect: selectedTextRect)
                        }
                    } else {
                        menu.showMenu(from: self, rect: bounds)
                    }
                }
            }
        }
    }

    /// 选择点击位置的单词
    private func selectWordAt(point: CGPoint) -> Bool {
        guard let text = self.text, !text.isEmpty else { return false }

        let characterIndex = layoutManager.characterIndex(for: point,
                                                        in: textContainer,
                                                        fractionOfDistanceBetweenInsertionPoints: nil)

        // 简单地选择包含该字符的整个单词
        let string = text as NSString
        let wordStart = string.rangeOfCharacter(from: .whitespacesAndNewlines,
                                                options: [.backwards],
                                                range: NSRange(location: 0, length: characterIndex + 1))
        let wordEnd = string.rangeOfCharacter(from: .whitespacesAndNewlines,
                                              options: [],
                                              range: NSRange(location: characterIndex, length: text.utf16.count - characterIndex))

        var startIndex = wordStart.location != NSNotFound ? wordStart.upperBound : 0
        var endIndex = wordEnd.location != NSNotFound ? wordEnd.lowerBound : text.utf16.count

        // 如果没找到边界，则选择单个字符
        if startIndex >= endIndex {
            startIndex = max(0, characterIndex - 1)
            endIndex = min(text.utf16.count, characterIndex + 2)
        }

        if let startPos = position(from: beginningOfDocument, offset: startIndex),
           let endPos = position(from: beginningOfDocument, offset: endIndex),
           let textRange = textRange(from: startPos, to: endPos) {
            selectedTextRange = textRange
            return true
        }

        return false
    }

    // MARK: - Menu Control

    private func hideMenu() {
        UIMenuController.shared.menuItems = nil
        UIMenuController.shared.hideMenu()
        resignFirstResponder()
    }

    /// 显示选择文本的菜单（用于长按选择添加下划线）
    func showSelectionMenu() {
        guard let range = selectedTextRange, let t = text(in: range), !t.isEmpty, canBecomeFirstResponder else { return }

        if becomeFirstResponder() {
            UIMenuController.shared.menuItems = [
                ChatSelectableTextView.underlineMenuItem,
                ChatSelectableTextView.removeUnderlineMenuItem
            ]

            let selectedTextRect = firstRect(for: range)
            // 修复崩溃：检查矩形是否有效，避免NaN坐标
            if selectedTextRect.isNull ||
               selectedTextRect.origin.x.isNaN ||
               selectedTextRect.origin.y.isNaN ||
               selectedTextRect.size.width.isNaN ||
               selectedTextRect.size.height.isNaN {
                UIMenuController.shared.showMenu(from: self, rect: bounds)
            } else {
                UIMenuController.shared.showMenu(from: self, rect: selectedTextRect)
            }
        }
    }

    /// 隐藏菜单并清理
    func hideCustomMenu() {
        hideMenu()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ChatSelectableTextView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // 允许与其他手势同时识别
    }
}
