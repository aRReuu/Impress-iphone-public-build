//
//  ImMemoryCardView.swift
//  aReuImpress-iPhone
//
//  记忆卡片视图 - 标准卡片类型的主要内容视图
//  功能：显示问题和答案、处理翻转动画、管理操作按钮
//  特色：支持语音播放、编辑功能、图片显示、划线标注
//
//  Created by aReu on 7/11/25.
//

import UIKit
import MarkdownKit

/// 记忆卡片视图
/// 负责展示标准类型卡片的内容，包括问题显示、答案展示和各种交互功能
/// 支持暗黑模式和无障碍访问，遵循苹果HIG设计规范
class ImMemoryCardView: UIView
{
    private var questionTextViewTopConstraint: NSLayoutConstraint!
    private var questionTextViewHeightConstraint: NSLayoutConstraint!
    private var questionTextViewCenterYConstraint: NSLayoutConstraint!
    private var answerContainerTopConstraintToCenter: NSLayoutConstraint!
    private var answerContainerTopConstraintToQuestionTextView: NSLayoutConstraint!

    private let cardView: UIView = {
        let view = UIView()
        return view
    }()

    let questionTextView: ImExtractTextView = {
        let textView = ImExtractTextView()
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .title1)
        textView.isEditable = false
        textView.textColor = contentColor
        textView.isScrollEnabled = false
        textView.textAlignment = .left
        textView.showsVerticalScrollIndicator = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        // 设置卡片摘录回调
        textView.onTextExtracted = { selectedText in
            // 卡片摘录逻辑：可以添加到学习笔记或创建新的学习卡片
            ImAlertController.alert(message: "已摘录到学习笔记：\(selectedText.prefix(20))...")
        }
        return textView
    }()

    // 答案容器
    private let answerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        view.backgroundColor = .clear
        return view
    }()

    private let answerTextView: ImExtractTextView = {
        let textView = ImExtractTextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textAlignment = .left
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        // 设置卡片答案摘录回调
        textView.onTextExtracted = { selectedText in
            // 卡片答案摘录逻辑
            ImAlertController.alert(message: "已摘录答案到学习笔记：\(selectedText.prefix(20))...")
        }
        return textView
    }()

    private let answerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var usesCompactV3Style = false
    private var isAnswerShown = false
    var answerIsRevealed: Bool { isAnswerShown }

    private var cardModel: ImCardModel?
    var onImageTapped: (() -> Void)?
    /// V3 observes answer visibility; legacy screens need not subscribe.
    var onAnswerVisibilityChanged: ((Bool) -> Void)?
    func revealAnswerIfNeeded() {
        if !isAnswerShown { showAnswer() }
    }

    // MARK: - Public Methods
    func updateCardContent(_ model: ImCardModel) {
        self.cardModel = model
        questionTextView.text = model.question
        updateQuestionTextViewHeight()

        // 更新答案内容
        let cardType = CardType(rawValue: model.cardType ?? 0) ?? .standard
        switch cardType {
        case .image:
            if let imageData = model.imageData {
                answerImageView.image = UIImage(data: imageData)
            }
        default:
            answerTextView.setMarkdownText(model.answer ?? "")
        }
    }

    // MARK: - Initialization
    convenience init(model: ImCardModel, v3Style: Bool = false)
    {
        self.init()
        self.usesCompactV3Style = v3Style
        if v3Style {
            // High-priority question text is primary label color, not muted gray.
            questionTextView.textColor = ImpressV3Appearance.primaryText
            questionTextView.font = ImpressV3Appearance.Typography.largeTitle
            answerTextView.font = ImpressV3Appearance.Typography.body
            questionTextView.adjustsFontForContentSizeCategory = true
            answerTextView.adjustsFontForContentSizeCategory = true
        }
        self.cardModel = model
        questionTextView.text = model.question
        setupUI()
        configureAnswerView(for: model)
        updateQuestionTextViewHeight()
        setupActions()
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        // 延迟到下一轮runloop执行高度更新，避免布局冲突
        scheduleHeightUpdate()
    }

    // MARK: - Setup
    private func setupUI()
    {
        cardView.frame = bounds
        addSubview(cardView)
        cardView.addSubview(questionTextView)
        cardView.addSubview(answerContainerView)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        questionTextView.translatesAutoresizingMaskIntoConstraints = false

        // V3.1 adapts to iPhone SE and keyboard/sheet safe areas. The
        // former 300×400 priority-999 minimum conflicted on compact screens.
        let cardViewWidthConstraint = cardView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor)
        let cardViewHeightConstraint = cardView.heightAnchor.constraint(equalTo: safeAreaLayoutGuide.heightAnchor)
        let cardViewMinWidthConstraint = cardView.widthAnchor.constraint(greaterThanOrEqualToConstant: usesCompactV3Style ? 220 : 300)
        let cardViewMinHeightConstraint = cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: usesCompactV3Style ? 200 : 400)
        cardViewMinWidthConstraint.priority = UILayoutPriority(usesCompactV3Style ? 250 : 999)
        cardViewMinHeightConstraint.priority = UILayoutPriority(usesCompactV3Style ? 250 : 999)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            cardViewWidthConstraint,
            cardViewHeightConstraint,
            cardViewMinWidthConstraint,
            cardViewMinHeightConstraint,
        ])


        // questionTextView 约束
        questionTextViewTopConstraint = questionTextView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: usesCompactV3Style ? 16 : 32)
        questionTextViewCenterYConstraint = questionTextView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        questionTextViewCenterYConstraint.isActive = true

        questionTextViewHeightConstraint = questionTextView.heightAnchor.constraint(equalToConstant: 44)
        // 设置高度约束优先级为高但非必需，允许在空间不足时压缩
        questionTextViewHeightConstraint.priority = UILayoutPriority(750)
        questionTextViewHeightConstraint.isActive = true
    
        NSLayoutConstraint.activate([
            questionTextView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: defaultSpacing),
            questionTextView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -defaultSpacing),
        ])

        answerContainerTopConstraintToCenter = answerContainerView.topAnchor.constraint(equalTo: cardView.centerYAnchor)
        answerContainerTopConstraintToQuestionTextView = answerContainerView.topAnchor.constraint(equalTo: questionTextView.bottomAnchor, constant: 8)
        answerContainerTopConstraintToCenter.isActive = true

        let answerContainerViewBottomConstraint = answerContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -defaultSpacing)
        answerContainerViewBottomConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            answerContainerView.leadingAnchor.constraint(equalTo: questionTextView.leadingAnchor),
            answerContainerView.trailingAnchor.constraint(equalTo: questionTextView.trailingAnchor),
            answerContainerViewBottomConstraint
        ])
    }

    private func configureAnswerView(for model: ImCardModel) {
        // Clear previous views
        answerContainerView.subviews.forEach { $0.removeFromSuperview() }

        let cardType = CardType(rawValue: model.cardType ?? 0) ?? .standard
        var currentAnswerView: UIView

        switch cardType {
        case .image:
            if let imageData = model.imageData {
                answerImageView.image = UIImage(data: imageData)
            }
            answerImageView.isUserInteractionEnabled = true
            let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
            answerImageView.addGestureRecognizer(imageTapGesture)
            currentAnswerView = answerImageView
        default: // .standard, .multipleChoice
            answerTextView.setMarkdownText(model.answer ?? "")
            currentAnswerView = answerTextView
        }
        
        answerContainerView.addSubview(currentAnswerView)
        currentAnswerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            currentAnswerView.topAnchor.constraint(equalTo: answerContainerView.topAnchor),
            currentAnswerView.leadingAnchor.constraint(equalTo: answerContainerView.leadingAnchor),
            currentAnswerView.trailingAnchor.constraint(equalTo: answerContainerView.trailingAnchor),
            currentAnswerView.bottomAnchor.constraint(equalTo: answerContainerView.bottomAnchor)
        ])
    }
    
    private func updateQuestionTextViewHeight()
    {
        // 增加安全检查，确保cardView有有效尺寸
        guard cardView.bounds.width > 0 && cardView.bounds.height > 0 else {
            return
        }

        let maxWidth = cardView.bounds.width - 40 // 减去左右边距
        guard maxWidth > 0 else {
            return
        }

        let size = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        let estimatedSize = questionTextView.sizeThatFits(size)

        // 只有当高度发生显著变化时才更新，避免不必要的布局计算
        let heightDifference = abs(questionTextViewHeightConstraint.constant - estimatedSize.height)
        guard heightDifference > 1.0 else {
            return
        }

        questionTextViewHeightConstraint.constant = estimatedSize.height
        // 移除强制布局调用，避免在布局过程中触发新的布局周期
    }

    /// 使用异步延迟更新高度，避免布局冲突
    private func scheduleHeightUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.updateQuestionTextViewHeight()
        }
    }

    private func setupActions()
    {
        // R03 requires the explicit external “查看答案” button. Tapping or
        // selecting text on the question must not unexpectedly reveal it.
        // Legacy cards retain their original tap-to-reveal contract.
        if usesCompactV3Style { return }
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(toggleAnswer))
        cardView.addGestureRecognizer(tapGesture)
        //
        let questionTapGesture = UITapGestureRecognizer(target: self,
                                                        action: #selector(toggleAnswer))
        questionTextView.addGestureRecognizer(questionTapGesture)
        questionTextView.isUserInteractionEnabled = true
    }

    @objc private func handleImageTap() {
        onImageTapped?()
    }

    // MARK: - Actions
    @objc private func toggleAnswer()
    {
        // In R03, revealed long answers remain readable and scrollable.
        // Incidental taps must not hide the answer or revoke rating readiness.
        if usesCompactV3Style && isAnswerShown { return }
        if !isAnswerShown {
            // 显示答案
            showAnswer()
        } else {
            // 隐藏答案，重新显示操作栏
            hideAnswer()
        }
    }

    private func showAnswer() {
        questionTextViewCenterYConstraint.isActive = false
        questionTextViewTopConstraint.isActive = true
        answerContainerTopConstraintToCenter.isActive = false
        answerContainerTopConstraintToQuestionTextView.isActive = true

        UIView.animate(withDuration: ImAnimationConfig.fadeAnimationDuration, animations: { [weak self] in
            guard let self = self else { return }
//            self.questionTextView.textColor = contentColor
            self.answerContainerView.alpha = 1
            self.layoutIfNeeded()
        }) { _ in
            self.isAnswerShown = true
            self.onAnswerVisibilityChanged?(true)
        }
    }

    private func hideAnswer() {
        questionTextViewTopConstraint.isActive = false
        questionTextViewCenterYConstraint.isActive = true
        answerContainerTopConstraintToQuestionTextView.isActive = false
        answerContainerTopConstraintToCenter.isActive = true

        UIView.animate(withDuration: ImAnimationConfig.fadeAnimationDuration, animations: { [weak self] in
            guard let self = self else { return }
//            self.questionTextView.textColor = contentColor
            self.answerContainerView.alpha = 0
            self.layoutIfNeeded()
        }) { _ in
            self.isAnswerShown = false
            self.onAnswerVisibilityChanged?(false)
        }
    }
}
