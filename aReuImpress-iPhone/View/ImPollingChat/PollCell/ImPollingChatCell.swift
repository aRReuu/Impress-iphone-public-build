import UIKit

class ImPollingChatCell: UITableViewCell {

    static let reuseIdentifier = "ImPollingChatCell"

    private let bubbleView = UIView()
    let messageTextView = ChatSelectableTextView()
    private let statusIndicatorStackView = UIStackView()
    private let typingIndicatorView = TypingIndicatorView()

    var scrollToBottomAction: (() -> Void)?

    // 下划线操作回调
    var onUnderlineOperation: ((ChatSelectableTextView.UnderlineOperation, UUID) -> Void)?

    private var botLeadingConstraint: NSLayoutConstraint!
    private var botTrailingConstraint: NSLayoutConstraint!
    private var userLeadingConstraint: NSLayoutConstraint!
    private var userTrailingConstraint: NSLayoutConstraint!

    // 用于存储原始文本（在搜索高亮时恢复用）
    private var originalText: String?

    // 性能优化：渲染缓存
    private var lastContentHash: String?
    private var lastUnderlinesHash: String?
    private var cachedAttributedText: NSAttributedString?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Deactivate all constraints to prevent conflicts when cells are reused.
        botLeadingConstraint.isActive = false
        botTrailingConstraint.isActive = false
        userLeadingConstraint.isActive = false
        userTrailingConstraint.isActive = false

        // 性能优化：清除渲染缓存，避免复用时显示错误内容
        lastContentHash = nil
        lastUnderlinesHash = nil
        cachedAttributedText = nil

        // 清理菜单状态，避免Cell复用时菜单配置混乱
        messageTextView.hideCustomMenu()
    }
    
    func configure(with message: ImPollingChatMessage) {
        messageTextView.font = nil
        messageTextView.text = nil
        messageTextView.attributedText = nil
        bubbleView.backgroundColor = .clear
        // 设置下划线操作回调
        messageTextView.onUnderlineOperation = { [weak self] operation in
            guard let self = self else { return }
            self.onUnderlineOperation?(operation, message.id)
        }

//         Handle different message statuses
        switch message.status {
        
        case .sending:
            typingIndicatorView.startAnimating()
            typingIndicatorView.isHidden = false
            messageTextView.isHidden = true
            bubbleView.backgroundColor = .clear
        case .sent:
            bubbleView.backgroundColor = secondaryBgColor
            typingIndicatorView.stopAnimating()
            typingIndicatorView.isHidden = true
            messageTextView.isHidden = false
        case .none, .failed:
            bubbleView.backgroundColor = .clear
            typingIndicatorView.stopAnimating()
            typingIndicatorView.isHidden = true
            messageTextView.isHidden = false
            break
        }

        // Configure bubble and text colors based on sender
        if message.sender == .user {
            messageTextView.font = UIFont.preferredFont(forTextStyle: .headline)
            messageTextView.textColor = contentColor
            messageTextView.text = message.content // 用户消息直接显示纯文本
            messageTextView.updateUnderlines(message.underlines ?? [], fullContent: message.content)
            botLeadingConstraint.isActive = false
            botTrailingConstraint.isActive = false
            userLeadingConstraint.isActive = true
            userTrailingConstraint.isActive = true
            statusIndicatorStackView.isHidden = true
        } else {
            // .bot
            messageTextView.textColor = contentColor
            configureMarkdownWithUnderlines(for: message)
            botLeadingConstraint.isActive = true
            botTrailingConstraint.isActive = true
            userLeadingConstraint.isActive = false
            userTrailingConstraint.isActive = false
            statusIndicatorStackView.isHidden = false
        }
    }
    
    private func setupViews() {
        backgroundColor = .clear
        statusIndicatorStackView.axis = .horizontal
        statusIndicatorStackView.spacing = 8
        statusIndicatorStackView.addArrangedSubview(typingIndicatorView)

        contentView.addSubview(bubbleView)
        contentView.addSubview(statusIndicatorStackView) // Add to contentView
        bubbleView.addSubview(messageTextView)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        messageTextView.translatesAutoresizingMaskIntoConstraints = false
        statusIndicatorStackView.translatesAutoresizingMaskIntoConstraints = false

        // This constraint helps the layout engine determine the width of the bubble view,
        // which is crucial for self-sizing cells with dynamic content. The priority is set
        // to .defaultHigh to avoid conflicts with required constraints.
        let maxWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor)
        maxWidthConstraint.priority = .defaultHigh
        maxWidthConstraint.isActive = true

        messageTextView.isEditable = false
        messageTextView.isSelectable = true
        messageTextView.isScrollEnabled = false
        messageTextView.backgroundColor = .clear
        messageTextView.font = UIFont.preferredFont(forTextStyle: .body)
        messageTextView.textColor = contentColor
        messageTextView.textContainerInset = .zero
        messageTextView.textContainer.lineFragmentPadding = 0

        bubbleView.layer.cornerRadius = defaultSpacing

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: defaultSpacing),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -defaultSpacing),

            messageTextView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: defaultSpacing),
            messageTextView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -defaultSpacing),
            messageTextView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: defaultSpacing),
            messageTextView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -defaultSpacing),

            // Constraints for the status indicator stack view
            statusIndicatorStackView.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            statusIndicatorStackView.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor)
        ])

        botLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: defaultSpacing)
        botTrailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -defaultSpacing)

        userLeadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: defaultSpacing * 3)
        userTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -defaultSpacing)
        selectionStyle = .none
    }
}

// MARK: - Performance Optimization
extension ImPollingChatCell {

    /// 配置Markdown渲染和下划线，带性能缓存优化
    private func configureMarkdownWithUnderlines(for message: ImPollingChatMessage) {
        let contentHash = message.content.hashValue.description
        let underlinesHash = (message.underlines ?? []).hashValue.description

        // 只有当内容或下划线真正改变时才重新渲染
        if contentHash == lastContentHash && underlinesHash == lastUnderlinesHash {
            // 如果有缓存，直接使用缓存的内容
            if let cachedText = cachedAttributedText {
                messageTextView.attributedText = cachedText
                return
            }
        }

        // 更新哈希值
        lastContentHash = contentHash
        lastUnderlinesHash = underlinesHash

        // 重新渲染Markdown
        messageTextView.setMarkdownText(message.content)

        // 直接在主线程渲染下划线，不再异步延迟
        messageTextView.updateUnderlines(message.underlines ?? [], fullContent: message.content)

        // 缓存渲染结果 (只对bot消息缓存，因为user消息是纯文本不复杂)
        cachedAttributedText = messageTextView.attributedText
    }
}

// MARK: - Search Highlighting
extension ImPollingChatCell {

    func highlightSearchResult(with searchText: String, range: NSRange, isMarkdownMessage: Bool = false, originalContent: String? = nil) {
        // 保存原始文本用于恢复
        if self.originalText == nil {
            self.originalText = originalContent ?? messageTextView.text
        }

        if isMarkdownMessage {
            // 机器人消息：markdown处理
            highlightMarkdownSearchResult(searchText, range: range, originalContent: originalContent ?? "")
        } else {
            // 用户消息：纯文本处理
            highlightPlainTextSearchResult(searchText, range: range)
        }
    }

    private func highlightPlainTextSearchResult(_ searchText: String, range: NSRange) {
        guard let text = messageTextView.text, !text.isEmpty else { return }

        // 创建当前显示的属性字符串副本
        var currentAttributedText: NSMutableAttributedString!

        if let existingAttributedText = messageTextView.attributedText {
            currentAttributedText = NSMutableAttributedString(attributedString: existingAttributedText)
        } else {
            currentAttributedText = NSMutableAttributedString(string: text)
            // 设置基本属性
            let defaultFont = messageTextView.font ?? UIFont.preferredFont(forTextStyle: .body)
            let defaultColor = messageTextView.textColor ?? titleColor
            let fullRange = NSRange(location: 0, length: text.utf16.count)
            currentAttributedText.addAttribute(.font, value: defaultFont, range: fullRange)
            currentAttributedText.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
        }

        // 先清除现有高亮
        currentAttributedText.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: currentAttributedText.length))

        // 添加新的高亮
        let newHighlightColor = highlightColor.withAlphaComponent(highlightAlpha)
        currentAttributedText.addAttribute(.backgroundColor, value: newHighlightColor, range: range)

        messageTextView.attributedText = currentAttributedText
    }

    private func highlightMarkdownSearchResult(_ searchText: String, range: NSRange, originalContent: String) {
        // 重新触发markdown渲染
        messageTextView.setMarkdownText(originalContent)

        guard let renderedAttributedText = messageTextView.attributedText,
              !renderedAttributedText.string.isEmpty else { return }

        let renderedString = renderedAttributedText.string

        // 在渲染后的字符串中查找搜索文本
        if let actualRange = findBestMatchingRange(searchText, in: renderedString, originalRange: range) {
            let mutableAttrText = NSMutableAttributedString(attributedString: renderedAttributedText)

            // 先清除所有现有高亮
            mutableAttrText.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutableAttrText.length))

            // 添加新高亮
            let newHighlightColor = highlightColor.withAlphaComponent(highlightAlpha)
            mutableAttrText.addAttribute(.backgroundColor, value: newHighlightColor, range: actualRange)

            messageTextView.attributedText = mutableAttrText
        }
    }

    private func findBestMatchingRange(_ searchText: String, in renderedText: String, originalRange: NSRange) -> NSRange? {
        guard let searchRange = renderedText.range(of: searchText, options: .caseInsensitive) else {
            return nil
        }

        // 简单返回第一个匹配，但可以根据需要优化为位置最接近的匹配
        return NSRange(searchRange, in: renderedText)
    }

    func clearSearchHighlight() {
        guard let attributedText = messageTextView.attributedText else { return }

        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedText)

        // 只移除背景色高亮，保留其他属性（比如markdown样式）
        mutableAttributedString.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutableAttributedString.length))

        messageTextView.attributedText = mutableAttributedString

        // 不重置originalText，让它保留以便后续使用
        // self.originalText = nil
    }
}
