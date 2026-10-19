//
//  ImMarkdownViewController.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 9/19/25.
//

import UIKit
import ImpressReviewCore
import MarkdownView

class ImMarkdownViewController: ImBaseViewController
{
    private let textView = ImExtractTextView.init(frame: .zero)
    private let searchController = UISearchController(searchResultsController: nil)
    private var note: ImNoteModel?
    private var originalText: String = ""
    private var originalAttributedText: NSAttributedString? // 保存初始的富文本
    private var lastSearchText: String = ""
    private var searchWorkItem: DispatchWorkItem? // 搜索任务
    private var searchRanges: [NSRange] = [] // 存储所有匹配项的范围
    private var currentSearchIndex: Int = -1 // 当前高亮的匹配项索引

    // 搜索导航按钮
    private var previousItem: UIBarButtonItem!
    private var nextItem: UIBarButtonItem!

    // 生成卡片浮动按钮
    private let generateCardButton = UIButton(type: .custom)
    private var isDragging = false
    private var initialCenter: CGPoint = .zero

    convenience init(note:ImNoteModel? = nil)
    {
        self.init()
        self.note = note
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupFloatingButtons()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideFloatingButtons()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // 屏幕旋转时重新定位按钮
        if generateCardButton.superview != nil {
            let buttonSize = defaultSpacing * 3
            let spacing = defaultSpacing
            // 确保按钮在新的安全区域内
            var newY = view.safeAreaLayoutGuide.layoutFrame.maxY - buttonSize - spacing
            if newY < view.safeAreaInsets.top + buttonSize {
                newY = view.safeAreaInsets.top + spacing + buttonSize
            }

            generateCardButton.frame.origin.y = newY

            // 确保水平位置也在安全区域内
            var newX = generateCardButton.frame.origin.x
            let minX = view.safeAreaInsets.left + spacing
            let maxX = view.bounds.width - view.safeAreaInsets.right - buttonSize - spacing

            if newX < minX {
                newX = minX
            } else if newX > maxX {
                newX = maxX
            }

            generateCardButton.frame.origin.x = newX
        }
    }

    private func setupUI()
    {
        view.backgroundColor = bgColor
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = note?.mainTitle

        // --- Performance Optimizations ---
        textView.isOpaque = true // Reduce GPU blending
        textView.dataDetectorTypes = [] // Disable data detectors to prevent overhead
        if #available(iOS 12.0, *) {
            textView.layoutManager.allowsNonContiguousLayout = true // Enable background layout processing
        }
        // --- End of Optimizations ---

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.alwaysBounceVertical = true
        textView.backgroundColor = bgColor
        textView.textColor = titleColor
        textView.isEditable = false // 不允许编辑内容
        let text = note?.markdownText ?? ""
        // 使用Down库渲染markdown文本
        textView.setMarkdownText(text)
        originalText = text
        // 记录初始 attributed 文本（使用Down渲染后的富文本）
        originalAttributedText = textView.attributedText

        // Explicit user action only: no implicit native Chat persistence.
        textView.onTextExtracted = { [weak self] selectedText in
            self?.showExcerptMenu(for: selectedText)
        }

        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        //
//        initMoreItemConfigure()
        searchControllerSetting()
        setupSearch()
    }

    private func setupFloatingButtons()
    {
        generateCardButton.setImage(UIImage(systemName: "plus.circle.fill"),
                                    for: .normal)
        generateCardButton.tintColor = .white
        generateCardButton.backgroundColor = funBtnColor
        generateCardButton.addTarget(self,
                                     action: #selector(generateCardFromNote),
                                     for: .touchUpInside)
        view.addSubview(generateCardButton)

        // 设置初始位置（左下角）
        let buttonSize = defaultSpacing * 4
        let spacing = defaultSpacing
        generateCardButton.frame = CGRect(
            x: spacing,
            y: view.safeAreaLayoutGuide.layoutFrame.maxY - buttonSize,
            width: buttonSize,
            height: buttonSize
        )
        generateCardButton.setDefaultCorner()
        // 添加拖拽手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        generateCardButton.addGestureRecognizer(panGesture)
    }

    private func hideFloatingButtons() {
        generateCardButton.removeFromSuperview()
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began:
            isDragging = false
            initialCenter = generateCardButton.center
        case .changed:
            // 移动按钮
            let newCenter = CGPoint(
                x: initialCenter.x + translation.x,
                y: initialCenter.y + translation.y
            )

            // 限制在安全区域内
            let safeAreaInsets = view.safeAreaInsets
            let buttonRadius: CGFloat = defaultSpacing * 1.5
            let minX = safeAreaInsets.left + buttonRadius
            let maxX = view.bounds.width - safeAreaInsets.right - buttonRadius
            let minY = safeAreaInsets.top + buttonRadius
            let maxY = view.bounds.height - safeAreaInsets.bottom - buttonRadius

            let clampedX = min(max(newCenter.x, minX), maxX)
            let clampedY = min(max(newCenter.y, minY), maxY)

            generateCardButton.center = CGPoint(x: clampedX, y: clampedY)
            isDragging = true
        case .ended:
            if !isDragging {
                // 如果没有拖拽，则执行点击事件
                generateCardFromNote()
            } else {
                // 自动吸附到屏幕边缘
                let screenWidth = view.bounds.width
                let centerX = generateCardButton.center.x

                UIView.animate(withDuration: 0.3) {
                    let targetX = centerX < screenWidth / 2 ?
                        defaultSpacing + defaultSpacing * 1.5 : // 左边
                        screenWidth - defaultSpacing - defaultSpacing * 1.5 // 右边

                    self.generateCardButton.center.x = targetX
                }
            }
        default:
            break
        }
    }

    private func setupSearch()
    {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜索文件内容..."
        searchController.searchBar.delegate = self
        definesPresentationContext = true

        // 创建键盘上方工具栏
        let accessoryView = createSearchAccessoryView()
        searchController.searchBar.inputAccessoryView = accessoryView
    }
    
    private func clearSearchHighlight()
    {
        // 恢复“原始富文本”，而不是用统一样式重建
        if let original = originalAttributedText {
            textView.attributedText = original
        } else {
            textView.text = originalText
        }
        // 重置搜索状态
        searchRanges.removeAll()
        currentSearchIndex = -1
        // 更新按钮状态
        updateSearchButtonsState()
        // 不强制滚回顶部，避免滚动位置突兀变化
        // textView.setContentOffset(.zero, animated: true)
    }

    /// 更新搜索导航按钮状态
    private func updateSearchButtonsState()
    {
        let hasMatches = !searchRanges.isEmpty
        previousItem?.isEnabled = hasMatches
        nextItem?.isEnabled = hasMatches

        // 如果只有一个匹配项，禁用上一个按钮（因为循环时上一个就是自己）
        if searchRanges.count == 1 {
            previousItem?.isEnabled = false
        }

        // 更新搜索结果计数显示
        updateSearchResultCount()
    }

    /// 更新搜索结果计数显示
    private func updateSearchResultCount()
    {
        if searchRanges.isEmpty {
            searchController.searchBar.placeholder = "搜索文件内容..."
        } else {
            let count = searchRanges.count
            let current = currentSearchIndex + 1 // 转换为1-based索引
            // 使用更明显的方式显示搜索结果计数
            searchController.searchBar.placeholder = "搜索结果: \(current)/\(count)"
            // 如果搜索栏有文本，我们可以在文本中显示计数
            if let searchText = searchController.searchBar.text, !searchText.isEmpty {
                searchController.searchBar.text = "\(searchText) (\(current)/\(count))"
            }
        }
    }
}


extension ImMarkdownViewController
{
    private func initMoreItemConfigure()
    {
        let assistItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"),
                                         style: .plain,
                                         target: self,
                                         action: nil)
        assistItem.tintColor = funBtnColor
        assistItem.menu = initMoreMenuActions()
        navigationItem.rightBarButtonItems = [assistItem]
    }
    
    /// 更多按钮逻辑事件
    private func initMoreMenuActions() -> UIMenu
    {
        let saveAction = UIAction(title: "保存(同步Obsidian)") { [weak self] _ in
            self?.saveButtonTapped()
        }
        return UIMenu(title: "", children: [saveAction])
    }
    
    @objc private func generateCardFromNote() {
        let content = textView.text ?? ""
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ImAlertController.warningAlert("笔记内容为空，无法生成卡片。")
            return
        }

        // 从笔记内容提取问题和答案
        // 使用第一行作为问题，其余作为答案
        let lines = content.components(separatedBy: .newlines)
        let question = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "笔记卡片"
//        let answer = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // 创建卡片模型
        var cardModel = ImCardModel()
        cardModel.question = question
//        cardModel.answer = answer.isEmpty ? content : answer // 如果没有多行内容，整个内容作为答案
        cardModel.cardType = CardType.standard.rawValue
        cardModel.createTime = Date()

        // FSRS initial state
        cardModel.state = CardState.new.rawValue
        cardModel.dueDate = Date()
        cardModel.difficulty = 0.0
        cardModel.stability = 0.0
        cardModel.reviewCount = 0
        cardModel.lapseCount = 0
        cardModel.relearningStep = 0

        // 弹出编辑界面让用户确认或修改
        let submitVC = ImSubmitViewController(submitModel: cardModel)
        submitVC.submitActionResult = { (updatedCard: ImCardModel) in

            let cardTable = ImDBTableType.card.description
            dbShare.insertToDB(intoTable: cardTable, with: [updatedCard]) { result in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    switch result {
                    case .success():
//                        ImAlertController.alert(message: "复习卡片创建成功！")
                        break
                    case .failure(let error):
                        ImAlertController.warningAlert("创建卡片失败：\(error.localizedDescription)")
                    }
                }
            }
        }
        present(submitVC, animated: true, completion: nil)
    }

    @objc private func saveButtonTapped()
    {
        // P0-0: never serialize the rendered UITextView back to source Markdown.
        // Rich text is not a lossless Obsidian AST. The original vault stays
        // read-only until the guarded P0-3 write coordinator is accepted.
        ImAlertController.warningAlert(
            "Obsidian 源文件目前为只读。请使用独立认知记录；双向写回必须经过版本比对和确认。")
    }

    /// 处理长按手势，实现摘录功能
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        // 获取长按位置的文本内容
        let location = gesture.location(in: textView)
        let characterIndex = textView.layoutManager.characterIndex(for: location, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        // 尝试获取当前行的文本内容作为摘录内容
        guard let textRange = getTextRangeAtLocation(characterIndex) else { return }

        let selectedText = (textView.text as NSString).substring(with: textRange)

        // 显示摘录菜单
        showExcerptMenu(for: selectedText)
    }

    /// 获取指定位置的文本范围（通常是一行或一段）
    private func getTextRangeAtLocation(_ characterIndex: Int) -> NSRange? {
        let text = textView.text as NSString
        let fullRange = NSRange(location: 0, length: text.length)

        // 查找当前行的范围
        var lineStart = characterIndex
        var lineEnd = characterIndex

        // 向前查找行开始
        while lineStart > 0 {
            let char = text.character(at: lineStart - 1)
            if char == 10 || char == 13 { // \n or \r
                break
            }
            lineStart -= 1
        }

        // 向后查找行结束
        while lineEnd < text.length {
            let char = text.character(at: lineEnd)
            if char == 10 || char == 13 { // \n or \r
                break
            }
            lineEnd += 1
        }

        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        return lineRange.length > 0 ? lineRange : nil
    }

    /// 显示摘录菜单
    private func showExcerptMenu(for selectedText: String) {
        let alertController = UIAlertController(
            title: "复制摘录",
            message: "确认后仅复制到系统剪贴板；不会保存到旧聊天记录或自动上传。",
            preferredStyle: .actionSheet)

        let excerptAction = UIAlertAction(title: "复制所选文字", style: .default) { _ in
            UIPasteboard.general.string = selectedText
        }

        let cancelAction = UIAlertAction(title: V3L("取消"), style: .cancel, handler: nil)

        alertController.addAction(excerptAction)
        alertController.addAction(cancelAction)

        // 在iPad上需要设置popoverPresentationController
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = textView
            popoverController.sourceRect = CGRect(x: textView.bounds.midX, y: textView.bounds.midY, width: 0, height: 0)
        }

        present(alertController, animated: true, completion: nil)
    }


}



// MARK: - UISearchBarDelegate

extension ImMarkdownViewController: UISearchBarDelegate
{
    private func searchControllerSetting()
    {
        let controller = UISearchController.init(searchResultsController: nil)
        controller.searchBar.placeholder = impressPageForNotesSearchBarDes
        controller.searchBar.delegate = self
        controller.searchBar.tintColor = titleColor
        controller.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    func searchBar(_ searchBar: UISearchBar,
                   textDidChange searchText: String)
    {
        lastSearchText = searchText
        guard !searchText.isEmpty else {
        clearSearchHighlight()
            return
    }
        highlightAndScroll(to: searchText)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar)
    {
        clearSearchHighlight()
        searchBar.text = nil
        searchBar.resignFirstResponder()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)
    {
        searchBar.resignFirstResponder()
        if let text = searchBar.text, !text.isEmpty {
            highlightAndScroll(to: text)
        }
    }



    /// 滚动到上一个搜索匹配项
    @objc private func scrollToPreviousMatch()
    {
        guard !searchRanges.isEmpty else { return }

        // 更新当前索引，循环处理
        currentSearchIndex = (currentSearchIndex - 1 + searchRanges.count) % searchRanges.count
        let range = searchRanges[currentSearchIndex]

        // 滚动到可见位置
        textView.scrollRangeToVisible(range)

        // 设置光标位置并添加临时高亮效果
        textView.selectedRange = NSRange(location: range.location, length: 0)

        // 添加临时高亮效果以突出显示当前匹配项
        highlightCurrentMatch(range)
    }

    /// 滚动到下一个搜索匹配项
    @objc private func scrollToNextMatch()
    {
        guard !searchRanges.isEmpty else { return }

        // 更新当前索引，循环处理
        currentSearchIndex = (currentSearchIndex + 1) % searchRanges.count
        let range = searchRanges[currentSearchIndex]

        // 滚动到可见位置
        textView.scrollRangeToVisible(range)

        // 设置光标位置并添加临时高亮效果
        textView.selectedRange = NSRange(location: range.location, length: 0)

        // 添加临时高亮效果以突出显示当前匹配项
        highlightCurrentMatch(range)
    }

    /// 高亮显示当前匹配项
    private func highlightCurrentMatch(_ range: NSRange)
    {
        // 创建当前文本的可变副本
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)

        // 先清除所有匹配项的高亮
        for searchRange in searchRanges {
            mutableText.removeAttribute(.backgroundColor, range: searchRange)
        }

        // 重新应用所有匹配项的高亮
        for searchRange in searchRanges {
            mutableText.addAttribute(.backgroundColor,
                                   value: highlightColor.withAlphaComponent(highlightAlpha + 0.05),
                                   range: searchRange)
        }

        // 对当前匹配项应用更明显的高亮
        mutableText.addAttribute(.backgroundColor,
                               value: highlightColor.withAlphaComponent(highlightAlpha + 0.2),
                               range: range)

        // 应用更新后的文本
        textView.attributedText = mutableText

        // 确保当前匹配项可见
        textView.scrollRangeToVisible(range)
    }



    /// 创建搜索键盘上方工具栏
    private func createSearchAccessoryView() -> UIToolbar
    {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        // 创建上一个按钮
        previousItem = UIBarButtonItem(image: UIImage(systemName: "chevron.up.circle.fill"),
                                       style: .plain,
                                       target: self,
                                       action: #selector(scrollToPreviousMatch))
        previousItem.tintColor = funBtnColor

        // 创建下一个按钮
        nextItem = UIBarButtonItem(image: UIImage(systemName: "chevron.down.circle.fill"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(scrollToNextMatch))
        nextItem.tintColor = funBtnColor

        // 创建弹性空间
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                            target: nil,
                                            action: nil)

        // 设置工具栏项目
        toolbar.items = [flexibleSpace, previousItem, nextItem, flexibleSpace]

        return toolbar
    }

    // 异步高亮文本并滚动到第一个匹配项，以避免阻塞UI线程
    private func highlightAndScroll(to keyword: String)
    {
        // 1. 取消之前的搜索任务，实现搜索防抖
        searchWorkItem?.cancel()

        // 2. 创建一个新的后台任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // 使用原始文本进行计算
            let base = (self.originalAttributedText ?? NSAttributedString(string: self.originalText))
            let mutable = NSMutableAttributedString(attributedString: base)
            let full = mutable.string as NSString

            var allRanges: [NSRange] = []
            var searchRange = NSRange(location: 0, length: full.length)

            // 检查任务在开始前是否已被取消
            guard !(self.searchWorkItem?.isCancelled ?? true) else { return }

            while searchRange.location < full.length {
                // 在循环的每次迭代中检查取消状态，以便尽快退出
                if self.searchWorkItem?.isCancelled ?? true { return }

                let found = full.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                if found.location == NSNotFound { break }

                mutable.addAttribute(.backgroundColor, value: highlightColor.withAlphaComponent(highlightAlpha + 0.05), range: found)
                allRanges.append(found)
                let next = found.location + found.length
                searchRange = NSRange(location: next, length: full.length - next)
            }

            // 在完成所有计算后，再次检查取消状态
            guard !(self.searchWorkItem?.isCancelled ?? true) else { return }

            // 3. 安全地切换回主线程来更新UI
            DispatchQueue.main.async {
                // 在更新UI之前做最后一次检查
                if !(self.searchWorkItem?.isCancelled ?? true) {
                    self.searchRanges = allRanges
                    self.currentSearchIndex = allRanges.isEmpty ? -1 : 0
                    self.textView.attributedText = mutable
                    if !allRanges.isEmpty {
                        let firstRange = allRanges[0]
                        self.textView.scrollRangeToVisible(firstRange)
                        // 将光标移动到找到的第一个匹配项的开头
                        self.textView.selectedRange = NSRange(location: firstRange.location, length: 0)
                        // 高亮显示第一个匹配项
                        self.highlightCurrentMatch(firstRange)
                    }
                    // 更新按钮状态
                    self.updateSearchButtonsState()
                }
            }
        }

        self.searchWorkItem = workItem

        // 4. 将任务分派到全局后台队列执行，以避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
}


// MARK: - P0 external Vault source viewer (never edits rendered NSAttributedString)

/// The source-of-truth is always the original byte buffer in ImVaultRawDocument.
/// Rich text is a disposable READ-ONLY projection and is never serialized back
/// as Markdown; unknown Obsidian syntax remains intact in source mode.
@MainActor
final class ImVaultDocumentController: UIViewController {
    private let document: ImVaultRawDocument
    private let readingView = UITextView()
    private let richView = MarkdownView()
    private let pathLabel = UILabel()
    private var preparedMarkdown: String?
    private var isSourceMode = false
    private let renderer = MarkdownKitRenderer()

    init(document: ImVaultRawDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(document:) required") }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pathLabel.text = V3L("只读") + " · " + document.identity.relativePath
        navigationItem.rightBarButtonItems?.first?.accessibilityLabel = V3L("编辑独立草稿")
        if let actions = navigationItem.rightBarButtonItems, actions.count >= 2 {
            actions[1].accessibilityLabel = V3L("切换 Markdown 源码")
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        title = URL(fileURLWithPath: document.identity.relativePath)
            .deletingPathExtension().lastPathComponent
        view.backgroundColor = ImpressV3Appearance.page
        navigationItem.largeTitleDisplayMode = .never
        ImpressV3Appearance.styleReadingTextView(readingView)
        ImpressV3Appearance.styleVaultDocument(richView)
        readingView.textAlignment = .left
        pathLabel.text = V3L("只读") + " · " + document.identity.relativePath
        pathLabel.font = ImpressV3Appearance.Typography.footnote
        pathLabel.adjustsFontForContentSizeCategory = true
        pathLabel.textColor = ImpressV3Appearance.secondaryText
        pathLabel.numberOfLines = 2
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.accessibilityIdentifier = "impress.notes.source-path"
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        readingView.translatesAutoresizingMaskIntoConstraints = false
        richView.translatesAutoresizingMaskIntoConstraints = false
        richView.isScrollEnabled = true
        // Do not load external Markdown images or navigate to arbitrary
        // web URLs without an explicit user request. Obsidian Vault is private.
        richView.onTouchLink = { [weak self] request in
            guard let url = request.url,
                  url.scheme == "https", url.host == "impress.invalid",
                  url.path == "/wiki",
                  let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                      .queryItems?.first(where: { $0.name == "target" })?.value else {
                // Never leave the app for an unapproved remote URL.
                return false
            }
            self?.followWikiLink(target)
            return false
        }
        view.addSubview(pathLabel)
        view.addSubview(readingView)
        view.addSubview(richView)
        let safe = view.safeAreaLayoutGuide
        let inset = ImpressV3Appearance.Metrics.screenInset
        let top = ImpressV3Appearance.Metrics.compactInset
        let bottom = ImpressV3Appearance.Metrics.compactInset
        let gap = ImpressV3Appearance.Metrics.rowSpacing
        NSLayoutConstraint.activate([
            pathLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: top),
            pathLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: inset),
            pathLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -inset),
            readingView.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: gap),
            readingView.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -bottom),
            readingView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: inset),
            readingView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -inset),
            richView.topAnchor.constraint(equalTo: readingView.topAnchor),
            richView.bottomAnchor.constraint(equalTo: readingView.bottomAnchor),
            richView.leadingAnchor.constraint(equalTo: readingView.leadingAnchor),
            richView.trailingAnchor.constraint(equalTo: readingView.trailingAnchor)
        ])
        let draft = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"), style: .plain,
            target: self, action: #selector(editDraft))
        draft.accessibilityLabel = V3L("编辑独立草稿")
        draft.accessibilityIdentifier = "impress.notes.draft"
        let source = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"), style: .plain,
            target: self, action: #selector(toggleSource))
        source.accessibilityLabel = V3L("切换 Markdown 源码")
        source.accessibilityIdentifier = "impress.notes.source-toggle"
        let generate = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.square"), style: .plain,
            target: self, action: #selector(generateAIQuestions))
        generate.accessibilityLabel = V3L("根据笔记生成综合问题")
        generate.accessibilityIdentifier = "impress.notes.generate-questions"
        let links = UIBarButtonItem(image: UIImage(systemName: "rectangle.stack"),
            style: .plain, target: self, action: #selector(openLinkedCards))
        links.accessibilityLabel = V3L("关联卡片")
        links.accessibilityIdentifier = "impress.notes.linked-cards"
        navigationItem.rightBarButtonItems = [draft, source, generate, links]
        renderBody()
        // Replaces only explicitly referenced local image embeds with bounded
        // in-memory data URIs. Never reads outside this authorized Vault.
        ImVaultReadSync.shared.prepareAuthorizedPreview(document) { [weak self] result in
            guard let self = self else { return }
            if case let .success(safeMarkdown) = result {
                self.preparedMarkdown = safeMarkdown
                if !self.isSourceMode { self.renderBody() }
            }
        }
    }

    private func renderBody() {
        readingView.isHidden = !isSourceMode
        richView.isHidden = isSourceMode
        if isSourceMode {
            readingView.text = document.markdown
            readingView.font = ImpressV3Appearance.Typography.code
            readingView.adjustsFontForContentSizeCategory = true
        } else {
            // Existing bundled MarkdownView/markdown-it renders tables,
            // fenced code, lists and headings without exposing a mutable text
            // buffer. Blocking external images avoids silent HTTP requests
            // from a private note. A future local-attachment bridge must
            // independently validate each file under the scoped Vault URL.
            // MarkdownKit-rich rendering runs inside a WKWebView. Literal
            // HTML from shared notes is inert in this read-only projection,
            // while raw source remains untouched and inspectable separately.
            let safeMarkdown = preparedMarkdown ??
                ImVaultSafetyProjection.withoutUntrustedImages(
                    ImVaultSafetyProjection.withCalloutHeadings(
                        ImVaultSafetyProjection.withWikiLinks(document.markdown)))
            // Only the prepared projection has excluded all ordinary image
            // URLs and can allow data: image embeds. The initial fallback
            // prohibits all images, including remote images.
            // Bundled MarkdownView's original CSS hardcodes white surfaces.
            // A central trusted media-query stylesheet adapts live to the
            // system appearance without re-reading or modifying Vault files.
            richView.load(markdown: safeMarkdown,
                          enableImage: preparedMarkdown != nil,
                          css: ImpressV3Appearance.markdownReaderCSS)
        }
        readingView.textAlignment = .left
    }

    @objc private func toggleSource() {
        isSourceMode.toggle()
        renderBody()
    }

    private func followWikiLink(_ rawTarget: String) {
        let withoutHeading = rawTarget.components(separatedBy: "#").first ?? rawTarget
        let withoutBlock = withoutHeading.components(separatedBy: "^").first ?? withoutHeading
        let target = withoutBlock.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, !target.hasPrefix("/"), !target.contains("\\"),
              !target.contains(":"), !target.split(separator: "/").contains("..") else {
            showVaultError("不安全的内部笔记链接", error: ImVaultSyncFailure.unsafePath)
            return
        }
        let normalized = target.lowercased().hasSuffix(".md") ? target : target + ".md"
        do {
            // Link resolution uses the identity of the authorized Vault,
            // never a title-only match against a different Vault or old WCDB.
            let indexed = try ImVaultPrivateStore.loadIndex(vaultID: document.identity.vaultID)
            let matches = indexed.filter { note in
                let relative = note.identity.relativePath
                if target.contains("/") {
                    return relative.compare(normalized, options: .caseInsensitive) == .orderedSame
                }
                return URL(fileURLWithPath: relative).lastPathComponent
                    .compare(normalized, options: .caseInsensitive) == .orderedSame
            }
            guard matches.count == 1, let note = matches.first else {
                let alert = UIAlertController(title: "无法打开内部链接",
                    message: matches.isEmpty
                        ? "目标笔记不存在或索引需要刷新。"
                        : "存在同名笔记。请使用包含完整相对目录的 Obsidian 链接。",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
                present(alert, animated: true)
                return
            }
            ImVaultReadSync.shared.read(note.identity) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(next):
                    self.navigationController?.pushViewController(
                        ImVaultDocumentController(document: next), animated: true)
                case let .failure(error):
                    self.showVaultError("目标笔记读取失败", error: error)
                }
            }
        } catch {
            showVaultError("内部链接索引不可用", error: error)
        }
    }

    @objc private func generateAIQuestions() {
        navigationController?.pushViewController(
            ImpressAIQuestionGenerationViewController(document: document), animated: true)
    }

    @objc private func openLinkedCards() {
        guard ImVaultReadOnlyProbe.shared.authorizedVaultID ==
                document.identity.vaultID else {
            showVaultError(V3L("Vault 授权已失效"),
                error: ImVaultCoreError.invalidVaultIdentity)
            return
        }
        do {
            let repository = try ImpressV3ReviewEnvironment.repository()
            let collection = ImpressV3CardCollectionViewController(
                repository: repository, sourceIdentity: document.identity)
            navigationController?.pushViewController(collection, animated: true)
        } catch {
            showVaultError(V3L("无法查询关联卡片"), error: error)
        }
    }

    @objc private func editDraft() {
        do {
            // A prior unsent version is NEVER overwritten by a newer source.
            let draft = try ImVaultPrivateStore.loadDraft(identity: document.identity)
                ?? ImVaultDraft(identity: document.identity,
                                baseText: document.markdown,
                                baseRawData: document.sourceBytes)
            navigationController?.pushViewController(
                ImVaultDraftEditorController(draft: draft), animated: true)
        } catch {
            showVaultError(V3L("无法打开独立草稿"), error: error)
        }
    }

    private func showVaultError(_ title: String, error: Error) {
        let alert = UIAlertController(title: title,
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(alert, animated: true)
    }
}

/// Source-preserving local editor. Each edit persists a private draft and
/// cannot change Obsidian's actual Markdown until full P0-5 approval.
@MainActor
final class ImVaultDraftEditorController: UIViewController, UITextViewDelegate {
    private var draft: ImVaultDraft
    private let sourceView = UITextView()
    private let persistenceQueue = DispatchQueue(label: "impress.vault.draft.persist",
                                                 qos: .utility)
    private var pendingAutosave: DispatchWorkItem?
    private var autosaveFailure: String?

    init(draft: ImVaultDraft) {
        self.draft = draft
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(draft:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = V3L("编辑私有草稿")
        view.backgroundColor = ImpressV3Appearance.page
        let notice = UILabel()
        notice.text = V3L("只保存在 Impress · 不直接修改 Obsidian")
        notice.textColor = ImpressV3Appearance.secondaryText
        notice.textAlignment = .center
        notice.font = ImpressV3Appearance.Typography.footnote
        notice.adjustsFontForContentSizeCategory = true
        notice.numberOfLines = 0
        notice.translatesAutoresizingMaskIntoConstraints = false

        sourceView.translatesAutoresizingMaskIntoConstraints = false
        sourceView.backgroundColor = ImpressV3Appearance.surface
        sourceView.textColor = ImpressV3Appearance.primaryText
        sourceView.font = ImpressV3Appearance.Typography.code
        sourceView.adjustsFontForContentSizeCategory = true
        sourceView.layer.cornerRadius = ImpressV3Appearance.Radius.field
        sourceView.text = draft.editedText
        sourceView.textContainerInset = UIEdgeInsets(top: 15, left: 15,
                                                    bottom: 24, right: 15)
        sourceView.delegate = self
        sourceView.isEditable = true
        ImpressSpeechAccessory.install(on: sourceView)
        NotificationCenter.default.addObserver(
            self, selector: #selector(flushDraftBeforeBackground),
            name: UIApplication.willResignActiveNotification, object: nil)
        view.addSubview(notice)
        view.addSubview(sourceView)
        NSLayoutConstraint.activate([
            notice.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            notice.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            notice.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sourceView.topAnchor.constraint(equalTo: notice.bottomAnchor, constant: 8),
            sourceView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: ImpressV3Appearance.Metrics.screenInset),
            sourceView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -ImpressV3Appearance.Metrics.screenInset),
            sourceView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ImpressV3Appearance.Metrics.compactInset)
        ])
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: V3L("查看差异"), style: .done, target: self,
                            action: #selector(showDiff)),
            UIBarButtonItem(title: V3L("保存草稿"), style: .plain, target: self,
                            action: #selector(saveDraftNow))
        ]
    }

    func textViewDidChange(_ textView: UITextView) {
        do {
            try draft.update(textView.text ?? "")
            scheduleDraftAutosave()
        } catch {
            // The visible text must not diverge from the last validated draft.
            textView.text = draft.editedText
            presentError("草稿超过安全大小限制", error)
        }
    }

    /// Debounce full Markdown JSON writes. Never enqueue a multi-megabyte
    /// encoding operation for every key stroke on a mobile keyboard.
    private func scheduleDraftAutosave() {
        pendingAutosave?.cancel()
        let snapshot = draft
        let work = DispatchWorkItem { [weak self] in
            do {
                try ImVaultPrivateStore.saveDraft(snapshot)
                DispatchQueue.main.async { self?.autosaveFailure = nil }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async {
                    self?.autosaveFailure = message
                    self?.navigationItem.prompt = "草稿自动保存失败 · 请使用保存草稿"
                }
            }
        }
        pendingAutosave = work
        persistenceQueue.asyncAfter(deadline: .now() + .milliseconds(650), execute: work)
    }

    /// A best-effort synchronous flush is important when iOS suspends a
    /// backgrounded app before a queued autosave has had a chance to run.
    @objc private func flushDraftBeforeBackground() {
        pendingAutosave?.cancel()
        do {
            try ImVaultPrivateStore.saveDraft(draft)
            autosaveFailure = nil
        } catch {
            autosaveFailure = error.localizedDescription
            navigationItem.prompt = "草稿保存失败 · 请检查可用存储空间"
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        pendingAutosave?.cancel()
        flushDraftBeforeBackground()
        super.viewWillDisappear(animated)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pendingAutosave?.cancel()
    }

    @objc private func saveDraftNow() {
        pendingAutosave?.cancel()
        do {
            try ImVaultPrivateStore.saveDraft(draft)
            autosaveFailure = nil
            navigationItem.prompt = nil
            let notice = UIAlertController(title: V3L("草稿已保存"),
                message: "仅存储在 Impress 私有目录，没有修改 Obsidian 文件。",
                preferredStyle: .alert)
            notice.addAction(UIAlertAction(title: V3L("确定"), style: .default))
            present(notice, animated: true)
        } catch { presentError("保存草稿失败", error) }
    }

    @objc private func showDiff() {
        do { try ImVaultPrivateStore.saveDraft(draft) }
        catch { presentError("无法持久化草稿", error); return }
        ImVaultReadSync.shared.read(draft.identity) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(source):
                let decision = self.draft.decision(against: source.sourceBytes)
                if decision == .conflict {
                    self.presentError("源文件已被其他应用修改",
                                      ImVaultSyncFailure.conflict)
                    return
                }
                let changes = ImVaultDiff.summary(
                    base: self.draft.baseText, edited: self.draft.editedText,
                    maximumLines: 200)
                self.navigationController?.pushViewController(
                    ImVaultDiffController(draft: self.draft, summary: changes.text,
                                          canApprove: changes.complete && decision == .safeToWrite),
                    animated: true)
            case let .failure(error):
                self.presentError("无法检查 Obsidian 当前版本", error)
            }
        }
    }

    private func presentError(_ title: String, _ error: Error) {
        let alert = UIAlertController(title: title,
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("确定"), style: .default))
        present(alert, animated: true)
    }
}

@MainActor
final class ImVaultDiffController: UIViewController {
    private let draft: ImVaultDraft
    private let summary: String
    private let canApprove: Bool

    init(draft: ImVaultDraft, summary: String, canApprove: Bool) {
        self.draft = draft
        self.summary = summary
        self.canApprove = canApprove
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(draft:summary:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "源文件差异"
        view.backgroundColor = ImpressV3Appearance.page
        let text = UITextView()
        text.isEditable = false
        text.isSelectable = true
        text.font = ImpressV3Appearance.Typography.compactCode
        text.adjustsFontForContentSizeCategory = true
        text.textColor = ImpressV3Appearance.primaryText
        text.backgroundColor = ImpressV3Appearance.surface
        text.layer.cornerRadius = ImpressV3Appearance.Radius.field
        text.text = summary
        text.textContainerInset = UIEdgeInsets(top: ImpressV3Appearance.Metrics.fieldPadding, left: ImpressV3Appearance.Metrics.fieldPadding,
                                             bottom: ImpressV3Appearance.Metrics.fieldPadding, right: ImpressV3Appearance.Metrics.fieldPadding)
        text.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ImpressV3Appearance.Metrics.compactInset),
            text.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ImpressV3Appearance.Metrics.compactInset),
            text.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: ImpressV3Appearance.Metrics.screenInset),
            text.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -ImpressV3Appearance.Metrics.screenInset)
        ])
        let save = UIBarButtonItem(title: "确认写回", style: .done,
                                   target: self, action: #selector(confirmWrite))
        // Production stays read-only. Debug QA can only enable this action
        // when the authorized folder is the explicitly named disposable copy.
        save.isEnabled = canApprove && ImVaultGuardedWrite.productionWriteEnabled
        navigationItem.rightBarButtonItem = save
        #if DEBUG
        if canApprove && !ImVaultGuardedWrite.productionWriteEnabled {
            navigationItem.prompt = V3L("真机 QA 仅支持独立的测试 Vault 副本")
            ImVaultGuardedWrite.checkQAVaultEligibility(for: draft.identity) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(true):
                    save.title = V3L("测试副本写回")
                    save.isEnabled = true
                    self.navigationItem.prompt = V3L("仅限测试副本；原始 Vault 仍保持只读")
                case .success(false):
                    self.navigationItem.prompt = V3L("请在「文件」App 选择 Impress-Write-Test-Vault 测试副本")
                case .failure(let error):
                    self.navigationItem.prompt = error.localizedDescription
                }
            }
        }
        #endif
    }

    @objc private func confirmWrite() {
        guard canApprove else { return }
        #if DEBUG
        let qaCopyRequested = !ImVaultGuardedWrite.productionWriteEnabled
        #else
        let qaCopyRequested = false
        #endif
        let alert = UIAlertController(
            title: qaCopyRequested ? V3L("确认修改独立测试副本？") :
                                     V3L("确认修改 Obsidian 源文件？"),
            message: qaCopyRequested
                ? V3L("仅操作「文件」中名称为 Impress-Write-Test-Vault 的独立副本。正式 Vault 不可写入。将重新核对原文 SHA-256，保存恢复副本后再尝试写入；请先自行复制重要笔记。")
                : V3L("将重新验证源文件 SHA-256，并先保存私有恢复副本。如果出现版本冲突会拒绝覆盖。"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: V3L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: qaCopyRequested ? V3L("确认测试副本写回") :
                                                              V3L("确认写回"),
                                      style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            ImVaultGuardedWrite.commitAuthorized(draft: self.draft,
                                                  userConfirmedDiff: true,
                                                  deviceQATestCopyConfirmed: qaCopyRequested) { result in
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                let content: String
                switch result {
                case .success: content = "写入已验证并保留恢复副本。"
                case let .failure(error): content = error.localizedDescription
                }
                let response = UIAlertController(title: "Vault 写回结果",
                    message: content, preferredStyle: .alert)
                response.addAction(UIAlertAction(title: V3L("确定"), style: .default))
                self.present(response, animated: true)
            }
        })
        present(alert, animated: true)
    }
}
