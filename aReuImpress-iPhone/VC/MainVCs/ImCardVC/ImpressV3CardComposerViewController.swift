import UIKit
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

// R04.2: V3 owns its editor, rather than mutating the legacy generic
// ImSubmitViewController used by chat drafts and older card workflows.
// Switching the selected type never destroys question/answer/image drafts.
struct ImpressV3CardDraft {
    struct Choice: Equatable {
        let id: UUID
        var text: String
        var isCorrect: Bool

        init(id: UUID = UUID(), text: String = "", isCorrect: Bool = false) {
            self.id = id
            self.text = text
            self.isCorrect = isCorrect
        }
    }

    var kind: CardType = .standard
    var question: String = ""
    var answer: String = ""
    var choices: [Choice] = [Choice(), Choice()]
    var allowsMultipleCorrect = false
    var imageData: Data?
    var sourceNotePath: String?

    func validatedInput(cardID: UUID = UUID()) throws -> WCDBV3CardInput {
        let prompt = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { throw ValidationError.missingQuestion }
        switch kind {
        case .standard:
            let response = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !response.isEmpty else { throw ValidationError.missingAnswer }
            return WCDBV3CardInput(cardID: cardID, question: prompt,
                                  answerText: response, cardType: CardType.standard.rawValue,
                                  sourceNotePath: sourceNotePath)
        case .multipleChoice:
            guard (2...12).contains(choices.count) else { throw ValidationError.optionCount }
            let labels = choices.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !labels.contains(where: { $0.isEmpty || $0.contains("\n") || $0.contains("\r") })
            else { throw ValidationError.emptyOption }
            guard Set(labels.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                             locale: .current) }).count == labels.count
            else { throw ValidationError.duplicateOption }
            let correct = choices.enumerated().compactMap { $0.element.isCorrect ? $0.offset : nil }
            guard !correct.isEmpty else { throw ValidationError.missingCorrect }
            guard allowsMultipleCorrect || correct.count == 1
            else { throw ValidationError.singleCorrectOnly }
            return WCDBV3CardInput(cardID: cardID, question: prompt,
                                  answerText: correct.map { labels[$0] }.joined(separator: "、"),
                                  choices: labels.joined(separator: "\n"),
                                  correctIndices: correct.map(String.init).joined(separator: ","),
                                  cardType: CardType.multipleChoice.rawValue,
                                  sourceNotePath: sourceNotePath)
        case .image:
            guard let data = imageData, !data.isEmpty else {
                throw ValidationError.missingImage
            }
            return WCDBV3CardInput(cardID: cardID, question: prompt, cardType: CardType.image.rawValue,
                                  imageData: data, sourceNotePath: sourceNotePath)
        }
    }

    enum ValidationError: LocalizedError {
        case missingQuestion, missingAnswer, optionCount, emptyOption
        case duplicateOption, missingCorrect, singleCorrectOnly, missingImage
        var errorDescription: String? {
            switch self {
            case .missingQuestion: return "请填写卡片的问题。"
            case .missingAnswer: return "问答卡片需要一个答案。"
            case .optionCount: return "选择题需要 2 到 12 个选项。"
            case .emptyOption: return "请填写全部选项；单个选项不能包含换行。"
            case .duplicateOption: return "选择题的选项不能重复。"
            case .missingCorrect: return "请直接点选至少一个正确答案。"
            case .singleCorrectOnly: return "单选模式只能标记一个正确答案；也可以切换到多选。"
            case .missingImage: return "请选择并完成压缩一张图片。"
            }
        }
    }
}

@MainActor
final class ImpressV3CardComposerViewController: UIViewController, PHPickerViewControllerDelegate {
    var onSave: ((WCDBV3CardInput) async throws -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let typePicker = UISegmentedControl(items: ["问答", "选择题", "图片"])
    private let questionView = UITextView()
    private let answerView = UITextView()
    private let qaSection = UIStackView()
    private let choiceSection = UIStackView()
    private let photoSection = UIStackView()
    private let choiceMode = UISegmentedControl(items: ["单选", "多选"])
    private let optionList = UIStackView()
    private let addOptionButton = UIButton(type: .system)
    private let imageButton = UIButton(type: .system)
    private let imagePreview = UIImageView()
    private var photoStatus = UILabel()
    private var choiceDrafts: [ImpressV3CardDraft.Choice]
    private var imageData: Data?
    private var processingPhoto = false
    private var saving = false
    private var originalDraft: ImpressV3CardDraft
    private var currentType: CardType
    private var saveItem: UIBarButtonItem?

    init(draft: ImpressV3CardDraft = ImpressV3CardDraft()) {
        self.originalDraft = draft
        self.currentType = draft.kind
        self.choiceDrafts = draft.choices
        self.imageData = draft.imageData
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError("init(draft:) required") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "新增卡片"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        let save = UIBarButtonItem(title: "保存", style: .done,
                                   target: self, action: #selector(saveCard))
        navigationItem.rightBarButtonItem = save
        saveItem = save

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        if #available(iOS 15.0, *) {
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor).isActive = true
        } else {
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        }

        typePicker.selectedSegmentIndex = currentType == .standard ? 0 :
            (currentType == .multipleChoice ? 1 : 2)
        // Use the iOS system-selected segment appearance, no faux glass tint.
        typePicker.addTarget(self, action: #selector(typeDidChange), for: .valueChanged)
        stack.addArrangedSubview(typePicker)

        questionView.backgroundColor = .secondarySystemGroupedBackground
        questionView.layer.cornerRadius = 12
        questionView.font = UIFont.preferredFont(forTextStyle: .body)
        questionView.adjustsFontForContentSizeCategory = true
        questionView.textColor = .label
        questionView.text = originalDraft.question
        questionView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        questionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        questionView.accessibilityLabel = "问题"
        stack.addArrangedSubview(makeLabeledGroup("问题", child: questionView))

        configureQA()
        configureChoices()
        configurePhoto()
        stack.addArrangedSubview(qaSection)
        stack.addArrangedSubview(choiceSection)
        stack.addArrangedSubview(photoSection)
        updateVisibleType()
    }

    private func verticalStack(spacing: CGFloat = 10) -> UIStackView {
        let v = UIStackView()
        v.axis = .vertical
        v.spacing = spacing
        return v
    }

    private func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    private func makeLabeledGroup(_ title: String, child: UIView) -> UIStackView {
        let group = verticalStack()
        let heading = UILabel()
        heading.text = title
        heading.font = UIFont.preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        group.addArrangedSubview(heading)
        group.addArrangedSubview(child)
        return group
    }

    private func configureQA() {
        qaSection.axis = .vertical
        qaSection.spacing = 10
        answerView.backgroundColor = .secondarySystemGroupedBackground
        answerView.layer.cornerRadius = 12
        answerView.font = UIFont.preferredFont(forTextStyle: .body)
        answerView.adjustsFontForContentSizeCategory = true
        answerView.textColor = .label
        answerView.text = originalDraft.answer
        answerView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        answerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 128).isActive = true
        answerView.accessibilityLabel = "答案"
        qaSection.addArrangedSubview(makeLabeledGroup("答案", child: answerView))
    }

    private func configureChoices() {
        choiceSection.axis = .vertical
        choiceSection.spacing = 14
        choiceMode.selectedSegmentIndex = originalDraft.allowsMultipleCorrect ? 1 : 0
        choiceMode.addTarget(self, action: #selector(modeDidChange), for: .valueChanged)
        choiceSection.addArrangedSubview(makeLabeledGroup("答案类型", child: choiceMode))
        optionList.axis = .vertical
        optionList.spacing = 8
        choiceSection.addArrangedSubview(makeLabeledGroup("选项（点选正确答案）", child: optionList))
        addOptionButton.setTitle("添加选项", for: .normal)
        if #available(iOS 15.0, *) {
            var c = UIButton.Configuration.borderedTinted()
            c.image = UIImage(systemName: "plus")
            c.title = "添加选项"
            c.imagePadding = 8
            addOptionButton.configuration = c
        }
        addOptionButton.addTarget(self, action: #selector(addOption), for: .touchUpInside)
        choiceSection.addArrangedSubview(addOptionButton)
        choiceSection.addArrangedSubview(caption("正确答案直接点击圆形标记；单选与多选均使用同一套 FSRS 复习评分。"))
        renderOptionRows()
    }

    private func configurePhoto() {
        photoSection.axis = .vertical
        photoSection.spacing = 12
        imageButton.setTitle("从照片选择图片", for: .normal)
        if #available(iOS 15.0, *) {
            var c = UIButton.Configuration.borderedTinted()
            c.title = "从照片选择图片"
            c.image = UIImage(systemName: "photo.on.rectangle")
            c.imagePadding = 8
            imageButton.configuration = c
        }
        imageButton.addTarget(self, action: #selector(selectPhoto), for: .touchUpInside)
        photoSection.addArrangedSubview(imageButton)
        imagePreview.contentMode = .scaleAspectFit
        imagePreview.backgroundColor = .secondarySystemGroupedBackground
        imagePreview.layer.cornerRadius = 12
        imagePreview.clipsToBounds = true
        imagePreview.heightAnchor.constraint(equalToConstant: 225).isActive = true
        imagePreview.image = imageData.flatMap { UIImage(data: $0) }
        imagePreview.isHidden = imageData == nil
        photoSection.addArrangedSubview(imagePreview)
        photoStatus = caption("仅访问所选图片；取消不修改草稿，保存前在本机压缩。")
        photoSection.addArrangedSubview(photoStatus)
    }

    @objc private func typeDidChange() {
        switch typePicker.selectedSegmentIndex {
        case 1: currentType = .multipleChoice
        case 2: currentType = .image
        default: currentType = .standard
        }
        // The three editors remain alive even when hidden; no data loss.
        updateVisibleType()
    }

    private func updateVisibleType() {
        qaSection.isHidden = currentType != .standard
        choiceSection.isHidden = currentType != .multipleChoice
        photoSection.isHidden = currentType != .image
    }

    @objc private func modeDidChange() {
        // Do not silently delete selected answers when changing modes.
        // If multiple are still selected in single mode, save validation explains why.
        renderOptionRows()
    }

    private func syncOptionEdits() {
        for view in optionList.arrangedSubviews {
            guard let row = view as? OptionRow,
                  let index = choiceDrafts.firstIndex(where: { $0.id == row.id }) else { continue }
            choiceDrafts[index].text = row.field.text ?? ""
        }
    }

    private func renderOptionRows() {
        syncOptionEdits()
        optionList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, choice) in choiceDrafts.enumerated() {
            let row = OptionRow(id: choice.id, index: index, correct: choice.isCorrect,
                                isMulti: choiceMode.selectedSegmentIndex == 1, text: choice.text)
            row.onSelect = { [weak self] id in self?.selectAnswer(id: id) }
            row.onDelete = { [weak self] id in self?.deleteOption(id: id) }
            row.onMove = { [weak self] id, offset in self?.moveOption(id: id, by: offset) }
            optionList.addArrangedSubview(row)
        }
    }

    private func selectAnswer(id: UUID) {
        syncOptionEdits()
        let single = choiceMode.selectedSegmentIndex == 0
        if single {
            for i in choiceDrafts.indices { choiceDrafts[i].isCorrect = choiceDrafts[i].id == id }
        } else if let i = choiceDrafts.firstIndex(where: { $0.id == id }) {
            choiceDrafts[i].isCorrect.toggle()
        }
        renderOptionRows()
    }

    @objc private func addOption() {
        guard choiceDrafts.count < 12 else { return }
        syncOptionEdits()
        choiceDrafts.append(.init())
        renderOptionRows()
    }

    private func deleteOption(id: UUID) {
        guard choiceDrafts.count > 2 else { return }
        syncOptionEdits()
        choiceDrafts.removeAll { $0.id == id }
        renderOptionRows()
    }

    private func moveOption(id: UUID, by offset: Int) {
        syncOptionEdits()
        guard let index = choiceDrafts.firstIndex(where: { $0.id == id }),
              choiceDrafts.indices.contains(index + offset) else { return }
        choiceDrafts.swapAt(index, index + offset)
        renderOptionRows()
    }

    private func draft() -> ImpressV3CardDraft {
        // This reads form controls without changing any stored business data.
        syncOptionEdits()
        return ImpressV3CardDraft(kind: currentType,
                                  question: questionView.text,
                                  answer: answerView.text,
                                  choices: choiceDrafts,
                                  allowsMultipleCorrect: choiceMode.selectedSegmentIndex == 1,
                                  imageData: imageData,
                                  sourceNotePath: originalDraft.sourceNotePath)
    }

    @objc private func saveCard() {
        guard !saving, !processingPhoto else { return }
        let input: WCDBV3CardInput
        do {
            input = try draft().validatedInput()
        } catch {
            showProblem(error.localizedDescription)
            return
        }
        guard let handler = onSave else { return }
        saving = true
        saveItem?.isEnabled = false
        Task { [weak self] in
            guard let self else { return }
            do {
                try await handler(input)
                self.dismiss(animated: true)
            } catch {
                self.saving = false
                self.saveItem?.isEnabled = true
                self.showProblem("卡片未保存：" + error.localizedDescription)
            }
        }
    }

    private func showProblem(_ text: String) {
        let alert = UIAlertController(title: "无法保存", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    @objc private func cancel() {
        let unchanged = questionView.text == originalDraft.question &&
            answerView.text == originalDraft.answer &&
            currentType == originalDraft.kind &&
            imageData == originalDraft.imageData
        syncOptionEdits()
        if unchanged && choiceDrafts == originalDraft.choices {
            dismiss(animated: true)
            return
        }
        let alert = UIAlertController(title: "放弃未保存的内容？",
                                      message: "取消不会写入 WCDB 或修改原始笔记。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "继续编辑", style: .cancel))
        alert.addAction(UIAlertAction(title: "放弃", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func selectPhoto() {
        guard !processingPhoto, !saving else { return }
        var cfg = PHPickerConfiguration()
        cfg.selectionLimit = 1
        cfg.filter = .images
        cfg.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        let fileType = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) ?? UTType.image.identifier
        guard provider.hasItemConformingToTypeIdentifier(fileType) else {
            showProblem("选中的项目不是受支持的图片。")
            return
        }
        processingPhoto = true
        saveItem?.isEnabled = false
        photoStatus.text = "正在本机压缩图片…"
        let kind: ImpressImageOptimizer.ContentKind =
            UTType(fileType)?.conforms(to: .png) == true ? .document : .photo
        provider.loadFileRepresentation(forTypeIdentifier: fileType) { [weak self] temporary, error in
            // Process inside the item-provider callback: its temporary file
            // is deleted once the callback returns. Never decode full 48MP.
            guard let temporary, let source = CGImageSourceCreateWithURL(temporary as CFURL, nil) else {
                DispatchQueue.main.async {
                    self?.photoFailed(error?.localizedDescription ?? "图片读取失败或 iCloud 尚未下载。")
                }
                return
            }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: kind == .document ? 2000 : 1280
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else {
                DispatchQueue.main.async { self?.photoFailed("无法读取图片缩略图。") }
                return
            }
            let image = UIImage(cgImage: thumbnail)
            let result = Result { try ImpressImageOptimizer.optimize(image, kind: kind) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.processingPhoto = false
                self.saveItem?.isEnabled = !self.saving
                switch result {
                case .success(let data):
                    self.imageData = data
                    self.imagePreview.image = UIImage(data: data)
                    self.imagePreview.isHidden = false
                    self.photoStatus.text = "图片已准备好 · \(data.count / 1024) KB"
                case .failure(let reason):
                    self.showProblem("压缩失败：" + reason.localizedDescription)
                    self.photoStatus.text = "图片未修改，请重试。"
                }
            }
        }
    }

    private func photoFailed(_ reason: String) {
        processingPhoto = false
        saveItem?.isEnabled = !saving
        photoStatus.text = "图片未修改，请重试。"
        showProblem(reason)
    }

    private final class OptionRow: UIStackView {
        let id: UUID
        let field = UITextField()
        var onSelect: ((UUID) -> Void)?
        var onDelete: ((UUID) -> Void)?
        var onMove: ((UUID, Int) -> Void)?

        init(id: UUID, index: Int, correct: Bool, isMulti: Bool, text: String) {
            self.id = id
            super.init(frame: .zero)
            axis = .horizontal
            alignment = .center
            spacing = 8
            let mark = UIButton(type: .system)
            mark.setImage(UIImage(systemName: correct
                                  ? (isMulti ? "checkmark.square.fill" : "largecircle.fill.circle")
                                  : (isMulti ? "square" : "circle")), for: .normal)
            mark.tintColor = .systemBlue
            mark.widthAnchor.constraint(equalToConstant: 44).isActive = true
            mark.heightAnchor.constraint(equalToConstant: 44).isActive = true
            mark.accessibilityLabel = "选项 \(index + 1) \(correct ? "正确" : "未标记")"
            mark.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.onSelect?(self.id)
            }, for: .touchUpInside)
            field.text = text
            field.placeholder = "选项 \(index + 1)"
            field.font = UIFont.preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.backgroundColor = .secondarySystemGroupedBackground
            field.borderStyle = .roundedRect
            field.accessibilityLabel = "选项 \(index + 1) 内容"
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            let actions = UIButton(type: .system)
            actions.setImage(UIImage(systemName: "ellipsis"), for: .normal)
            actions.widthAnchor.constraint(equalToConstant: 44).isActive = true
            actions.heightAnchor.constraint(equalToConstant: 44).isActive = true
            actions.accessibilityLabel = "调整或删除选项 \(index + 1)"
            actions.menu = UIMenu(children: [
                UIAction(title: "上移", image: UIImage(systemName: "arrow.up")) { [weak self] _ in
                    guard let self else { return }; self.onMove?(self.id, -1)
                },
                UIAction(title: "下移", image: UIImage(systemName: "arrow.down")) { [weak self] _ in
                    guard let self else { return }; self.onMove?(self.id, 1)
                },
                UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                    guard let self else { return }; self.onDelete?(self.id)
                }
            ])
            actions.showsMenuAsPrimaryAction = true
            addArrangedSubview(mark)
            addArrangedSubview(field)
            addArrangedSubview(actions)
        }

        required init(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    }
}
