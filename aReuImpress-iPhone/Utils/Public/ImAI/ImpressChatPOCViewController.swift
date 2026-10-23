#if DEBUG
import UIKit
import ImpressReviewCore

/// Isolated zero-network vertical slice. Launch with -ImpressChatPOC.
/// Never instantiated by the production Chat navigation or persistence path.
@MainActor
final class ImpressChatPOCViewController: UIViewController, UITextViewDelegate, UICollectionViewDelegate, UIScrollViewDelegate {
    private struct Turn {
        let id: UUID
        let isUser: Bool
        var text: String
        var stream: ImpressChatPOCStream?
    }
    private struct Row: Equatable {
        let user: Bool
        let text: String
        let kind: ImpressChatPOCBlock.Kind
        let depth: Int
        let stable: Bool
    }
    private let transcript: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                              heightDimension: .estimated(58))
            let item = NSCollectionLayoutItem(layoutSize: size)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 8
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 16, leading: 14, bottom: 16, trailing: 14)
            return section
        }
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    private let composer = UIView()
    private let input = UITextView()
    private let action = UIButton(type: .system)
    private var height: NSLayoutConstraint?
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var turns: [Turn] = []
    private var rows: [String: Row] = [:]
    private var playback: Task<Void, Never>?
    private enum ScrollMode { case followingBottom, readingHistory, keyboardTransition, restoring }
    private var scrollMode: ScrollMode = .followingBottom
    private var publishedIDs: [String] = []
    private var isRenderingQueued = false
    private var lastRenderedAt = CFAbsoluteTimeGetCurrent()
    /// Counts real decoded SSE delta events, not animation frames.
    private var receivedDeltas = 0
    private let fixture = """
    # 从碎片到结构化理解

    **第一性原理**是区分事实、假设与解释。下面演示真实增量文本增长，不使用真实模型或用户数据。

    ## 可执行步骤

    1. 先记录需要解释的问题。
       - 明确已有证据
       - 标出尚未证实的假设
    2. 以最少的概念解释问题。

    > 这是一个离线合成回复；不会调用收费 API。

    ~~~swift
    let question = "为什么需要稳定内容块？"
    print(question)
    ~~~

    | 关注点 | 原型行为 |
    | --- | --- |
    | 滚动 | 用户上滑后停止强制跟随 |
    | 流式 | 只替换未封闭的末尾块 |

    $$
    E = mc^2
    $$

    链接：[本地示例](https://example.org)。包含 emoji 🧠 与中文。
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chat Renderer · POC"
        view.backgroundColor = ImpressV3Appearance.page
        let empty = UILabel()
        empty.text = "从一个问题开始"
        empty.font = .preferredFont(forTextStyle: .title2)
        empty.textColor = .secondaryLabel
        empty.textAlignment = .center
        empty.accessibilityIdentifier = "impress.chat.poc.empty"
        transcript.backgroundView = empty
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "合成压力样本", image: UIImage(systemName: "chart.bar.xaxis"),
            primaryAction: nil, menu: UIMenu(children: [100, 1_000, 5_000].map { size in
                UIAction(title: String(size) + " 条消息") { [weak self] _ in
                    self?.loadSyntheticHistory(count: size)
                }
            }))
        NotificationCenter.default.addObserver(self,
            selector: #selector(refreshDynamicType),
            name: UIContentSizeCategory.didChangeNotification, object: nil)
        navigationItem.largeTitleDisplayMode = .never

        transcript.backgroundColor = .clear
        transcript.keyboardDismissMode = .interactive
        transcript.delegate = self
        transcript.register(ImpressChatPOCCell.self, forCellWithReuseIdentifier: "block")
        transcript.register(ImpressChatPOCStructuredCell.self,
                            forCellWithReuseIdentifier: "structured")
        transcript.register(ImpressChatPOCMathCell.self,
                            forCellWithReuseIdentifier: "math")
        transcript.accessibilityIdentifier = "impress.chat.poc.transcript"
        dataSource = UICollectionViewDiffableDataSource<Int, String>(
            collectionView: transcript) { [weak self] collection, indexPath, id in
                guard let self, let row = self.rows[id] else { return nil }
                if !row.user && (row.kind == .code || row.kind == .table),
                   let cell = collection.dequeueReusableCell(
                    withReuseIdentifier: "structured", for: indexPath)
                        as? ImpressChatPOCStructuredCell {
                    cell.configure(markdown: row.text, kind: row.kind, stable: row.stable)
                    return cell
                }
                if !row.user && row.kind == .math,
                   let cell = collection.dequeueReusableCell(
                    withReuseIdentifier: "math", for: indexPath) as? ImpressChatPOCMathCell {
                    cell.configure(row.text, stable: row.stable)
                    return cell
                }
                guard let cell = collection.dequeueReusableCell(
                    withReuseIdentifier: "block", for: indexPath) as? ImpressChatPOCCell
                else { return nil }
                cell.configure(rowText: row.text, kind: row.kind,
                               headingLevel: row.depth, user: row.user,
                               stable: row.stable)
                cell.accessibilityIdentifier = "impress.chat.poc.block." + id
                return cell
            }

        input.delegate = self
        input.font = UIFont.preferredFont(forTextStyle: .body)
        input.adjustsFontForContentSizeCategory = true
        input.backgroundColor = .clear
        input.isScrollEnabled = false
        input.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        input.accessibilityIdentifier = "impress.chat.poc.input"
        input.accessibilityLabel = "消息输入"
        action.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        action.accessibilityIdentifier = "impress.chat.poc.send-stop"
        action.accessibilityLabel = "发送"
        action.addTarget(self, action: #selector(sendOrStop), for: .touchUpInside)
        action.widthAnchor.constraint(equalToConstant: 44).isActive = true
        action.heightAnchor.constraint(equalToConstant: 44).isActive = true
        composer.layer.cornerRadius = 22
        composer.backgroundColor = .secondarySystemBackground

        let row = UIStackView(arrangedSubviews: [input, action])
        row.axis = .horizontal
        row.alignment = .bottom
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        transcript.translatesAutoresizingMaskIntoConstraints = false
        composer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transcript)
        view.addSubview(composer)
        composer.addSubview(row)
        let inputHeight = input.heightAnchor.constraint(equalToConstant: 44)
        height = inputHeight
        NSLayoutConstraint.activate([
            transcript.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            transcript.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transcript.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            transcript.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -6),
            composer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            composer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            composer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: composer.leadingAnchor, constant: 7),
            row.trailingAnchor.constraint(equalTo: composer.trailingAnchor, constant: -7),
            row.topAnchor.constraint(equalTo: composer.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -4),
            inputHeight
        ])
        showRows()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func refreshDynamicType() {
        // Reconfigure visible items, including already stable blocks.
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func loadSyntheticHistory(count: Int) {
        playback?.cancel()
        playback = nil
        turns = []
        turns.reserveCapacity(count)
        let longParagraph = "这一条消息包含中文、Unicode 🧠 与结构化的历史上下文。"
        for index in 0..<count {
            if index % 2 == 0 {
                turns.append(Turn(id: UUID(), isUser: true,
                    text: "合成提问 #" + String(index) + "：" + longParagraph, stream: nil))
            } else {
                var engine = ImpressChatPOCStream()
                engine.start()
                engine.append("## 第 " + String(index) + " 条回复\n\n" +
                    longParagraph + "\n\n")
                engine.finish()
                turns.append(Turn(id: UUID(), isUser: false, text: "", stream: engine))
            }
        }
        scrollMode = .followingBottom
        publishedIDs = []
        rows = [:]
        var empty = NSDiffableDataSourceSnapshot<Int, String>()
        empty.appendSections([0])
        dataSource.apply(empty, animatingDifferences: false)
        showRows()
        updateAction()
    }

    func textViewDidChange(_ textView: UITextView) {
        let measured = textView.sizeThatFits(
            CGSize(width: max(1, textView.bounds.width), height: .greatestFiniteMagnitude)).height
        height?.constant = min(148, max(44, measured))
        textView.isScrollEnabled = measured > 148
        updateAction()
    }

    @objc private func sendOrStop() {
        if let active = playback {
            active.cancel()
            playback = nil
            guard let i = turns.indices.last, turns[i].stream != nil else { return }
            var stream = turns[i].stream!
            stream.stop()
            turns[i].stream = stream
            updateAction()
            showRows()
            return
        }
        let value = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            // Explicit regenerate after Stop/failure. The old partial answer
            // stays intact; we append a new attempt without duplicating input.
            guard canRegenerate else { return }
        } else {
            turns.append(Turn(id: UUID(), isUser: true, text: value, stream: nil))
        }
        var model = ImpressChatPOCStream()
        model.start()
        turns.append(Turn(id: UUID(), isUser: false, text: "", stream: model))
        input.text = ""
        textViewDidChange(input)
        input.resignFirstResponder()
        scrollMode = .followingBottom
        showRows()
        updateAction()

        // Replay genuine fragmented OpenAI-format SSE byte frames. This
        // exercises the EXACT offline UTF-8/SSE/terminal decoder used by the
        // Core tests; it is no longer a fake substring typing animation.
        let frames = makeOfflineFrames(for: fixture)
        receivedDeltas = 0
        playback = Task { [weak self] in
            guard let self else { return }
            var transport = ImpressChatPOCReplay(provider: .openAIChat)
            do {
                for bytes in frames {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 22_000_000)
                    try Task.checkCancellation()
                    for output in try transport.append(bytes) {
                        switch output {
                        case .delta(let text):
                            self.receivedDeltas += 1
                            self.append(text)
                        case .completed:
                            self.finish()
                            return
                        case .failed:
                            self.failStream()
                            return
                        }
                    }
                }
                // Socket close without [DONE] is a failure, not completion.
                for output in try transport.finish() {
                    switch output {
                    case .delta(let text): self.append(text)
                    case .completed: self.finish(); return
                    case .failed: self.failStream(); return
                    }
                }
                if !transport.normalizer.isCompleted { self.failStream() }
            } catch is CancellationError {
                // Stop was handled synchronously; no late completed write.
            } catch {
                self.failStream()
            }
        }
        updateAction()
    }

    /// Mixed SSE buffer reads are intentionally not aligned to event lines,
    /// UTF-8 scalar boundaries, or JSON boundaries.
    private func makeOfflineFrames(for markdown: String) -> [Data] {
        let scalars = Array(markdown.unicodeScalars)
        var wire = Data()
        for i in stride(from: 0, to: scalars.count, by: 12) {
            let delta = scalars[i..<min(scalars.count, i + 12)]
                .map { String($0) }.joined()
            let packet: [String: Any] = [
                "choices": [["delta": ["content": delta]]]
            ]
            guard let encoded = try? JSONSerialization.data(withJSONObject: packet),
                  let line = String(data: encoded, encoding: .utf8) else { continue }
            wire.append(Data(("data: " + line + "\n\n").utf8))
        }
        wire.append(Data("data: [DONE]\n\n".utf8))
        let bytes = Array(wire)
        var frames: [Data] = []
        var offset = 0, count = 0
        while offset < bytes.count {
            let size = min(29 + count % 17, bytes.count - offset)
            frames.append(Data(bytes[offset..<(offset + size)]))
            offset += size
            count += 1
        }
        return frames
    }

    private func failStream() {
        guard let index = turns.indices.last, var stream = turns[index].stream,
              stream.phase == .streaming else { return }
        stream.fail()
        turns[index].stream = stream
        playback?.cancel()
        playback = nil
        updateAction()
        showRows()
    }

    private func append(_ text: String) {
        guard let i = turns.indices.last, var stream = turns[i].stream else { return }
        stream.append(text)
        turns[i].stream = stream
        // Up to 30Hz view commits, independent from transport events.
        // All tokens update the model immediately; no visible updates are lost.
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastRenderedAt >= 1.0 / 30.0 {
            lastRenderedAt = now
            showRows()
        } else if !isRenderingQueued {
            isRenderingQueued = true
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 34_000_000)
                guard let self else { return }
                self.isRenderingQueued = false
                self.lastRenderedAt = CFAbsoluteTimeGetCurrent()
                self.showRows()
            }
        }
    }

    private func finish() {
        guard let i = turns.indices.last, var stream = turns[i].stream else { return }
        stream.finish()
        turns[i].stream = stream
        playback = nil
        updateAction()
        showRows()
    }

    private var canRegenerate: Bool {
        guard let stream = turns.last?.stream else { return false }
        return stream.phase == .stopped || stream.phase == .failed
    }

    private func updateAction() {
        let running = playback != nil
        let retry = !running && input.text.trimmingCharacters(
            in: .whitespacesAndNewlines).isEmpty && canRegenerate
        let symbol = running ? "stop.circle.fill" :
            (retry ? "arrow.clockwise.circle.fill" : "arrow.up.circle.fill")
        action.setImage(UIImage(systemName: symbol), for: .normal)
        action.accessibilityLabel = running ? "停止生成" :
            (retry ? "重新生成" : "发送")
        action.accessibilityValue = running ? "SSE 增量事件：" + String(receivedDeltas) : nil
    }

    private func showRows() {
        var fresh: [String: Row] = [:]
        var identifiers: [String] = []
        for turn in turns {
            let prefix = turn.id.uuidString
            if turn.isUser {
                let id = "user-" + prefix
                identifiers.append(id)
                fresh[id] = Row(user: true, text: turn.text, kind: .paragraph,
                                depth: 0, stable: true)
                continue
            }
            if let stream = turn.stream {
                for block in stream.blocks {
                    let id = "assistant-" + prefix + "-" + String(block.id)
                    identifiers.append(id)
                    fresh[id] = Row(user: false, text: block.markdown, kind: block.kind,
                                    depth: block.headingLevel, stable: block.stable)
                }
                if stream.phase != .streaming {
                    let id = "status-" + prefix
                    identifiers.append(id)
                    let value = stream.phase == .completed ? "已完成" :
                                stream.phase == .stopped ? "已停止 · 保留部分回复" : "生成失败"
                    fresh[id] = Row(user: false, text: value, kind: .quote,
                                    depth: 0, stable: true)
                }
            }
        }

        let snapshotBefore = dataSource.snapshot()
        let oldIDs = Set(snapshotBefore.itemIdentifiers)
        let changed = identifiers.filter { oldIDs.contains($0) && rows[$0] != fresh[$0] }
        let anchor = transcript.indexPathsForVisibleItems.sorted().first.flatMap {
            index -> (String, CGFloat)? in
            guard let id = dataSource.itemIdentifier(for: index),
                  let attributes = transcript.layoutAttributesForItem(at: index) else { return nil }
            return (id, attributes.frame.minY - transcript.contentOffset.y)
        }
        rows = fresh
        transcript.backgroundView?.isHidden = !identifiers.isEmpty
        var snapshot = dataSource.snapshot()
        if identifiers == publishedIDs {
            if changed.isEmpty { return }
            snapshot.reconfigureItems(changed)
        } else if publishedIDs.count <= identifiers.count &&
                    Array(identifiers.prefix(publishedIDs.count)) == publishedIDs {
            snapshot.appendItems(Array(identifiers.dropFirst(publishedIDs.count)))
            if !changed.isEmpty { snapshot.reconfigureItems(changed) }
        } else {
            snapshot = NSDiffableDataSourceSnapshot<Int, String>()
            snapshot.appendSections([0])
            snapshot.appendItems(identifiers)
            if !changed.isEmpty { snapshot.reconfigureItems(changed) }
        }
        publishedIDs = identifiers
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            self.transcript.layoutIfNeeded()
            if self.scrollMode == .followingBottom {
                if let index = identifiers.indices.last {
                    self.transcript.scrollToItem(at: IndexPath(item: index, section: 0),
                                                  at: .bottom, animated: false)
                }
            } else if let (id, dy) = anchor,
                      let index = identifiers.firstIndex(of: id),
                      let attributes = self.transcript.layoutAttributesForItem(
                        at: IndexPath(item: index, section: 0)) {
                let offset = max(-self.transcript.adjustedContentInset.top,
                                 attributes.frame.minY - dy)
                self.transcript.setContentOffset(
                    CGPoint(x: self.transcript.contentOffset.x, y: offset), animated: false)
            }
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollMode = .readingHistory
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        if !willDecelerate { updateFollowMode(scrollView) }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateFollowMode(scrollView)
    }
    private func updateFollowMode(_ scroll: UIScrollView) {
        let remaining = scroll.contentSize.height -
            (scroll.contentOffset.y + scroll.bounds.height)
        scrollMode = remaining < 64 ? .followingBottom : .readingHistory
    }
}

@MainActor
private final class ImpressChatPOCCell: UICollectionViewCell {
    private let bubble = UIView()
    private let body = UITextView()
    private let quoteStripe = UIView()
    private let horizontalRule = UIView()
    private var assistantLeading: NSLayoutConstraint!
    private var userWidth: NSLayoutConstraint!
    override init(frame: CGRect) {
        super.init(frame: frame)
        bubble.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        body.isEditable = false
        body.isSelectable = true
        body.isScrollEnabled = false
        body.backgroundColor = .clear
        body.textContainerInset = .zero
        body.textContainer.lineFragmentPadding = 0
        body.dataDetectorTypes = [.link]
        body.adjustsFontForContentSizeCategory = true
        contentView.addSubview(bubble)
        bubble.addSubview(body)
        bubble.addSubview(quoteStripe)
        bubble.addSubview(horizontalRule)
        quoteStripe.translatesAutoresizingMaskIntoConstraints = false
        quoteStripe.backgroundColor = .tertiaryLabel
        quoteStripe.layer.cornerRadius = 1.5
        horizontalRule.translatesAutoresizingMaskIntoConstraints = false
        horizontalRule.backgroundColor = .separator
        assistantLeading = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        userWidth = bubble.widthAnchor.constraint(equalTo: contentView.widthAnchor,
                                                   multiplier: 0.82)
        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor),
            body.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            body.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
            body.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            body.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            quoteStripe.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 2),
            quoteStripe.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 4),
            quoteStripe.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -4),
            quoteStripe.widthAnchor.constraint(equalToConstant: 3),
            horizontalRule.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            horizontalRule.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            horizontalRule.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
            horizontalRule.heightAnchor.constraint(equalToConstant: 1)
        ])
        assistantLeading.isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    func configure(rowText: String, kind: ImpressChatPOCBlock.Kind,
                   headingLevel: Int, user: Bool, stable: Bool) {
        assistantLeading.isActive = !user
        userWidth.isActive = user
        bubble.backgroundColor = user ? .tertiarySystemFill : .clear
        bubble.layer.cornerRadius = user ? 19 : 0
        quoteStripe.isHidden = kind != .quote || user
        horizontalRule.isHidden = kind != .divider || user
        let original = rowText
        var displayed = rowText
        if kind == .heading && headingLevel > 0 {
            displayed = String(rowText.dropFirst(headingLevel))
                .trimmingCharacters(in: .whitespaces)
        } else if kind == .quote {
            displayed = rowText.split(separator: "\n",
                omittingEmptySubsequences: false).map {
                let value = $0.trimmingCharacters(in: .whitespaces)
                return value.hasPrefix(">") ? String(value.dropFirst())
                    .trimmingCharacters(in: .whitespaces) : value
            }.joined(separator: "\n")
        }
        let baseSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let headingScale: [CGFloat] = [1.0, 1.58, 1.42, 1.28, 1.15, 1.07, 1.0]
        let depth = min(6, max(1, headingLevel))
        let font = kind == .heading ?
            UIFont.systemFont(ofSize: baseSize * headingScale[depth], weight: .bold) :
            UIFont.preferredFont(forTextStyle: .body)
        body.textColor = .label
        body.font = font
        body.isSelectable = true
        body.isHidden = kind == .divider
        if kind == .divider { displayed = " " }

        if !user && kind == .list {
            body.attributedText = structuredList(displayed, font: font)
        } else if !user,
                  let parsed = try? AttributedString(markdown: displayed) {
            let attributed = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
            if kind == .heading {
                attributed.addAttribute(.font, value: font,
                    range: NSRange(location: 0, length: attributed.length))
            }
            body.attributedText = attributed
        } else {
            body.attributedText = NSAttributedString(string: displayed, attributes: [
                .font: font, .foregroundColor: UIColor.label
            ])
        }
        // Source markdown is only an accessibility/copy fallback. Do not
        // claim that unsupported attachment links were actually loaded.
        body.accessibilityLabel = original + (stable ? "" : "，生成中")
    }

    private func structuredList(_ markdown: String, font: UIFont) -> NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        for raw in markdown.components(separatedBy: "\n") {
            let indentSpaces = raw.prefix(while: { $0 == " " }).count
            let clean = raw.trimmingCharacters(in: .whitespaces)
            let dash = ["- ", "* ", "+ "].first { clean.hasPrefix($0) }
            let ordered = clean.prefix(while: { $0.isNumber })
            let numberMarker = !ordered.isEmpty &&
                (clean.dropFirst(ordered.count).hasPrefix(". ") ||
                 clean.dropFirst(ordered.count).hasPrefix(") "))
            let depth = min(8, indentSpaces / 2)
            let marker = dash != nil ? "• " : (numberMarker ? String(ordered) + ". " : "")
            let content: String
            if let dash { content = String(clean.dropFirst(dash.count)) }
            else if numberMarker { content = String(clean.dropFirst(ordered.count + 2)) }
            else { content = clean }
            let paragraph = NSMutableParagraphStyle()
            let start = CGFloat(depth) * 18 + 6
            let inset = marker.isEmpty ? 0 : 20.0
            paragraph.firstLineHeadIndent = start
            paragraph.headIndent = start + inset
            paragraph.paragraphSpacing = 5
            let value = marker + content + "\n"
            let styled: NSAttributedString
            if let parsed = try? AttributedString(markdown: value) {
                styled = NSAttributedString(parsed)
            } else {
                styled = NSAttributedString(string: value)
            }
            let built = NSMutableAttributedString(attributedString: styled)
            built.addAttributes([
                .font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.label
            ], range: NSRange(location: 0, length: built.length))
            output.append(built)
        }
        return output
    }
}
#endif
