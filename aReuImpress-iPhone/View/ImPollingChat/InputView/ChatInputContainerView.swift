import UIKit

/// 聊天输入容器视图 - 使用业内标准方案实现占位符
class ChatInputContainerView: UIView {

    // MARK: - UI Components
    private let inputBackgroundView = UIView()
    private let messageInputTextView = UITextView()
    private let placeholderLabel = UILabel()  // 占位符标签
    private let micButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)

    // MARK: - Properties
    private var heightConstraint: NSLayoutConstraint?
    private var maxHeightConstraint: NSLayoutConstraint?
    /// 输入框最大高度（可配置）
    private var maxInputHeight: CGFloat = 150 {
        didSet {
            updateHeightConstraints()
        }
    }

    private var placeholderText: String = "" {
        didSet {
            placeholderLabel.text = placeholderText
        }
    }

    /// 输入文本变化回调
    var onTextChanged: ((String) -> Void)?

    /// 发送按钮点击回调
    var onSendMessage: (() -> Void)?

    /// 麦克风按钮点击回调
    var onMicPressed: (() -> Void)? {
        didSet { updateButtonVisibility() }
    }

    /// 获取当前输入文本
    var text: String {
        get { messageInputTextView.text }
        set {
            messageInputTextView.text = newValue
            updatePlaceholderVisibility()
            updateButtonVisibility()
        }
    }

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupViews() {
        // 设置主背景色为透明，与整体设计保持一致
        backgroundColor = .clear

        // 输入框背景视图 - 使用系统三级填充色，更符合HIG规范
        inputBackgroundView.backgroundColor = .secondarySystemGroupedBackground
        inputBackgroundView.layer.cornerRadius = 16
        inputBackgroundView.layer.masksToBounds = true

        // Setup text view - 优化字体和样式
        messageInputTextView.font = UIFont.preferredFont(forTextStyle: .body)
        messageInputTextView.adjustsFontForContentSizeCategory = true
        messageInputTextView.backgroundColor = .clear // 透明背景，让背景视图的颜色显示
        messageInputTextView.isScrollEnabled = false
        messageInputTextView.textContainerInset = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16) // 更大的内边距
        messageInputTextView.delegate = self
        messageInputTextView.text = ""
        messageInputTextView.textColor = titleColor

        // 占位符标签 - 完全独立的UI组件
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = subTitleColor
        placeholderLabel.numberOfLines = 0  // 支持多行
        placeholderLabel.isHidden = false  // 初始显示占位符

        // Setup buttons - 优化按钮样式和交互
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.addTarget(self, action: #selector(sendButtonPressed), for: .touchUpInside)
        sendButton.tintColor = funBtnColor
        sendButton.isHidden = true

        if #available(iOS 15.0, *) {
            var style = UIButton.Configuration.plain()
            style.image = UIImage(systemName: "arrow.up.circle.fill")
            style.baseForegroundColor = .systemBlue
            sendButton.configuration = style
        }
        sendButton.accessibilityLabel = "发送消息"

        // 麦克风按钮优化
        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = subTitleColor
        micButton.addTarget(self, action: #selector(micButtonPressed), for: .touchUpInside)

        if #available(iOS 15.0, *) {
            var style = UIButton.Configuration.plain()
            style.image = UIImage(systemName: "mic.fill")
            style.baseForegroundColor = .secondaryLabel
            micButton.configuration = style
        }
        micButton.accessibilityLabel = "语音输入"
        micButton.isHidden = true

        // Add subviews
        addSubview(inputBackgroundView)
        inputBackgroundView.addSubview(messageInputTextView)
        inputBackgroundView.addSubview(placeholderLabel)
        addSubview(sendButton)
        addSubview(micButton)
    }

    private func setupConstraints() {
        [inputBackgroundView, messageInputTextView, placeholderLabel, sendButton, micButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Background view - 添加适当的外边距，更符合HIG规范
            inputBackgroundView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            inputBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            inputBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            inputBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            // Text view - 优化文本视图的布局
            messageInputTextView.topAnchor.constraint(equalTo: inputBackgroundView.topAnchor, constant: 2),
            messageInputTextView.leadingAnchor.constraint(equalTo: inputBackgroundView.leadingAnchor, constant: 4),
            messageInputTextView.bottomAnchor.constraint(equalTo: inputBackgroundView.bottomAnchor, constant: -2),

            // 占位符标签 - 与文本视图对齐
            placeholderLabel.leadingAnchor.constraint(equalTo: messageInputTextView.leadingAnchor, constant: 12), // 考虑textContainerInset
            placeholderLabel.trailingAnchor.constraint(equalTo: messageInputTextView.trailingAnchor, constant: -12),
            placeholderLabel.centerYAnchor.constraint(equalTo: messageInputTextView.centerYAnchor),

            // Send button - 优化按钮位置和大小
            sendButton.trailingAnchor.constraint(equalTo: inputBackgroundView.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: inputBackgroundView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44),

            // Mic button - 优化麦克风按钮布局
            micButton.leadingAnchor.constraint(equalTo: messageInputTextView.trailingAnchor, constant: 8),
            micButton.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: inputBackgroundView.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 44),
            micButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Dynamic height constraints - 优化高度约束
        heightConstraint = inputBackgroundView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52) // 稍微增大最小高度
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true

        maxHeightConstraint = inputBackgroundView.heightAnchor.constraint(lessThanOrEqualToConstant: maxInputHeight + 16) // 考虑背景视图的高度
        maxHeightConstraint?.isActive = true
    }

    /// 更新高度约束
    private func updateHeightConstraints() {
        maxHeightConstraint?.constant = maxInputHeight
    }

    // MARK: - Public Methods
    /// 设置输入框最大高度
    func setMaxInputHeight(_ height: CGFloat) {
        maxInputHeight = height
    }

    /// 设置占位符文本
    func setPlaceholder(_ text: String) {
        placeholderText = text
        updatePlaceholderVisibility()
    }

    /// 设置用户输入文本（处理文本颜色和按钮状态）
    func setUserInputText(_ text: String) {
        messageInputTextView.text = text
        messageInputTextView.textColor = titleColor
        updatePlaceholderVisibility()
        updateButtonVisibility()
    }

    /// 清空输入
    func clearInput() {
        messageInputTextView.text = ""
        messageInputTextView.textColor = titleColor
        messageInputTextView.isScrollEnabled = false // 强制禁用滚动
        updatePlaceholderVisibility()
        updateButtonVisibility()

        // 强制重置所有高度相关状态到初始状态
        resetInputHeightForcefully()
    }

    // MARK: - Private Methods
    private func updatePlaceholderVisibility() {
        let hasText = !messageInputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        placeholderLabel.isHidden = hasText
    }

    private func updateButtonVisibility() {
        let hasText = !messageInputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isPlaceholder = messageInputTextView.textColor == subTitleColor

        sendButton.isHidden = hasText && !isPlaceholder ? false : true
        micButton.isHidden = !(onMicPressed != nil && !hasText)

        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }

    @objc private func sendButtonPressed() {
        // Native UIButton.Configuration provides standard pressed feedback.
        onSendMessage?()
    }

    @objc private func micButtonPressed() {
        // 添加触摸反馈动画
        UIView.animate(withDuration: 0.15, animations: {
            self.micButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.micButton.transform = CGAffineTransform.identity
            }
        }

        // 调用回调
        onMicPressed?()
    }
}

// MARK: - UITextViewDelegate
extension ChatInputContainerView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        updateButtonVisibility()

        // 动态控制滚动：如果内容高度超过最大高度，启用滚动
        let contentHeight = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude)).height
        textView.isScrollEnabled = contentHeight > maxInputHeight

        // 实时调整输入框高度
        updateInputViewHeight()

        onTextChanged?(textView.text)
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        // 确保占位符正确隐藏
        updatePlaceholderVisibility()

        // Use the system's focus response; do not scale the entire input.
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // 确保占位符正确显示
        updatePlaceholderVisibility()

        // The system restores native appearance when editing ends.
    }

    // MARK: - Helper Methods
    private func updateInputViewHeight() {
        // 根据文本内容动态调整输入框高度
        let fixedWidth = messageInputTextView.frame.size.width
        let newSize = messageInputTextView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))

        // 确保高度在合理范围内
        let newHeight = min(max(newSize.height, 52), maxInputHeight)

        // 平滑过渡到新高度
        UIView.animate(withDuration: 0.1) {
            self.heightConstraint?.constant = newHeight
            self.layoutIfNeeded()
        }
    }

    /// 重置输入框高度到最小值
    private func resetInputHeight() {
        UIView.animate(withDuration: 0.2) {
            self.heightConstraint?.constant = 52 // 重置到最小高度
            self.layoutIfNeeded()
        }
    }

    /// 强制重置输入框到最初状态，处理所有边界条件
    private func resetInputHeightForcefully() {
        // 停止所有正在进行的动画
        inputBackgroundView.layer.removeAllAnimations()
        messageInputTextView.layer.removeAllAnimations()
        layer.removeAllAnimations()

        // 临时禁用动画以立即重置状态
        UIView.setAnimationsEnabled(false)

        // 强制恢复变换状态到原始状态
        inputBackgroundView.transform = CGAffineTransform.identity

        // 强制重置高度约束到最小值
        heightConstraint?.constant = 52
        maxHeightConstraint?.constant = maxInputHeight + 16

        // 强制布局更新（无动画）
        layoutIfNeeded()

        // 重新启用动画
        UIView.setAnimationsEnabled(true)

        // 确保文本视图状态正确
        messageInputTextView.isScrollEnabled = false
        messageInputTextView.setContentOffset(.zero, animated: false)
    }
}
