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
    private var followingBottom = true
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
        navigationItem.largeTitleDisplayMode = .never

        transcript.backgroundColor = .clear
        transcript.keyboardDismissMode = .interactive
        transcript.delegate = self
        transcript.register(ImpressChatPOCCell.self, forCellWithReuseIdentifier: "block")
        transcript.accessibilityIdentifier = "impress.chat.poc.transcript"
        dataSource = UICollectionViewDiffableDataSource<Int, String>(
            collectionView: transcript) { [weak self] collection, indexPath, id in
                guard let self,
                      let row = self.rows[id],
                      let cell = collection.dequeueReusableCell(
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

    func textViewDidChange(_ textView: UITextView) {
        let measured = textView.sizeThatFits(
            CGSize(width: max(1, textView.bounds.width), height: .greatestFiniteMagnitude)).height
        height?.constant = min(148, max(44, measured))
        textView.isScrollEnabled = measured > 148
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
        guard !value.isEmpty else { return }
        turns.append(Turn(id: UUID(), isUser: true, text: value, stream: nil))
        var model = ImpressChatPOCStream()
        model.start()
        turns.append(Turn(id: UUID(), isUser: false, text: "", stream: model))
        input.text = ""
        textViewDidChange(input)
        input.resignFirstResponder()
        followingBottom = true
        showRows()
        updateAction()

        let scalars = Array(fixture.unicodeScalars)
        let fragments = stride(from: 0, to: scalars.count, by: 5).map { i in
            scalars[i..<min(scalars.count, i + 5)].map { String($0) }.joined()
        }
        playback = Task { [weak self] in
            for fragment in fragments {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 55_000_000)
                if Task.isCancelled { return }
                self?.append(fragment)
            }
            self?.finish()
        }
        updateAction()
    }

    private func append(_ text: String) {
        guard let i = turns.indices.last, var stream = turns[i].stream else { return }
        stream.append(text)
        turns[i].stream = stream
        showRows()
    }

    private func finish() {
        guard let i = turns.indices.last, var stream = turns[i].stream else { return }
        stream.finish()
        turns[i].stream = stream
        playback = nil
        updateAction()
        showRows()
    }

    private func updateAction() {
        let running = playback != nil
        action.setImage(UIImage(systemName: running ? "stop.circle.fill" : "arrow.up.circle.fill"),
                        for: .normal)
        action.accessibilityLabel = running ? "停止生成" : "发送"
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
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(identifiers)
        snapshot.reconfigureItems(changed)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            self.transcript.layoutIfNeeded()
            if self.followingBottom {
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
        followingBottom = false
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        let remaining = scrollView.contentSize.height -
            (scrollView.contentOffset.y + scrollView.bounds.height)
        if remaining < 64 { followingBottom = true }
    }
}

@MainActor
private final class ImpressChatPOCCell: UICollectionViewCell {
    private let bubble = UIView()
    private let body = UITextView()
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
            body.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12)
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
        var display = rowText
        if kind == .heading && headingLevel > 0 {
            display = String(rowText.dropFirst(headingLevel))
                .trimmingCharacters(in: .whitespaces)
        }
        let mono = kind == .code || kind == .table || kind == .math
        body.font = mono ? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                         : UIFont.preferredFont(forTextStyle: kind == .heading ? .headline : .body)
        body.textColor = .label
        body.attributedText = nil
        if !mono && !user, let parsed = try? AttributedString(markdown: display) {
            body.attributedText = NSAttributedString(parsed)
        } else {
            body.text = display
        }
        body.backgroundColor = mono ? .secondarySystemBackground : .clear
        body.layer.cornerRadius = mono ? 10 : 0
        body.accessibilityLabel = display + (stable ? "" : "，生成中")
    }
}
#endif
