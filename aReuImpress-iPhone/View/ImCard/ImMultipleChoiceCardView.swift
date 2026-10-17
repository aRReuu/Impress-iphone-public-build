//
//  ImMultipleChoiceCardView.swift
//  aReuImpress-iPhone
//
//  多选题卡片视图 - 选择题类型卡片的内容视图
//  功能：显示题目和选项、处理选择逻辑、展示答案和反馈
//  特色：支持单选和多选、实时反馈、答案验证和视觉提示
//
//  Created by aReu on 2025/10/1.
//

import UIKit

/// 多选题卡片视图
/// 负责展示选择题类型卡片的内容，包括题目显示、选项交互和答案验证
/// 支持单选和多选模式，提供即时的视觉反馈和答案验证
class ImMultipleChoiceCardView: UIView {
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        label.textColor = titleColor
        label.textAlignment = .center
        label.numberOfLines = 2
        label.backgroundColor = .clear
        return label
    }()

    private let optionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = defaultSpacing * 2
        return stackView
    }()
    
    private let buttonMargin: CGFloat = 16
    
    private var model: ImCardModel
    private let usesNativeOptionButtons: Bool
    private var optionButtons: [UIButton] = []
    private var selectedIndices: Set<Int> = []
    private var isAnswerShown = false
    var answerIsRevealed: Bool { isAnswerShown }

    /// The user must still make a separate Tinder swipe to rate FSRS.
    var onAnswerRevealed: (() -> Void)?

    init(model: ImCardModel, usesNativeOptionButtons: Bool = false) {
        self.model = model
        self.usesNativeOptionButtons = usesNativeOptionButtons
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        if usesNativeOptionButtons {
            questionLabel.numberOfLines = 0
            optionsStackView.spacing = 9
            backgroundColor = ImpressV3Appearance.surface
            questionLabel.font = ImpressV3Appearance.Typography.cardTitle
            questionLabel.textColor = ImpressV3Appearance.primaryText
        }
        setupViews()
        configure(with: model)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // 将其他视图添加到容器中
        addSubview(questionLabel)
        addSubview(optionsStackView)
        // 设置内部视图约束
        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: defaultSpacing * 2),
            questionLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: defaultSpacing),
            questionLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -defaultSpacing),

            optionsStackView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: defaultSpacing * 2),
            optionsStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: buttonMargin),
            optionsStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -buttonMargin),
            optionsStackView.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -defaultSpacing * 2)
        ])
    }
    
    
    func configure(with model: ImCardModel) {
        questionLabel.text = model.question
        
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        optionButtons.removeAll()
        
        if let choicesString = model.choices {
            let choices = choicesString.split(separator: "\n").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            
            for (index, choice) in choices.enumerated() {
                let button = createOptionButton(title: choice, tag: index)
                optionsStackView.addArrangedSubview(button)
                optionButtons.append(button)
            }
        }
    }
    
    private func createOptionButton(title: String, tag: Int) -> UIButton {
        // V3 uses Apple's native button type; old card screens retain
        // their existing rendering and touch animation unchanged.
        let button = UIButton(type: usesNativeOptionButtons ? .system : .custom)
        button.setTitle(title, for: .normal)
        button.tag = tag
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.setTitleColor(titleColor, for: .normal)
        button.backgroundColor = .clear
        button.contentHorizontalAlignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant:
            usesNativeOptionButtons ? 44 : 48).isActive = true
        if usesNativeOptionButtons {
            button.titleLabel?.font = ImpressV3Appearance.Typography.body
            button.setTitleColor(ImpressV3Appearance.primaryText, for: .normal)
            button.backgroundColor = ImpressV3Appearance.surface
            button.layer.cornerRadius = ImpressV3Appearance.Radius.field
            button.layer.borderWidth = 0
            button.contentHorizontalAlignment = .leading
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.accessibilityHint = "选项选择不计入复习评分"
        }

        // UIKit handles native pressed-state appearance in V3. Retain the
        // old custom touch transform solely for the legacy card screen.
        if !usesNativeOptionButtons {
            button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        button.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)

        return button
    }

    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }
    
    @objc private func optionTapped(_ sender: UIButton) {
        guard !isAnswerShown else { return }

        let index = sender.tag
        let correctIndices = Set(model.correctAnswerIndices?.split(separator: ",").compactMap { Int(String($0)) } ?? [])

        // 单选题直接显示答案
        if correctIndices.count <= 1 {
            selectedIndices.insert(index)
            showAnswer()
            return
        }

        // --- 多选题逻辑 ---
        let isCorrectSelection = correctIndices.contains(index)

        if isCorrectSelection {
            // 1. 如果点击了正确的选项
            selectedIndices.insert(index)
            updateButtonAppearance()

            // 检查是否已选出所有正确答案
            if selectedIndices == correctIndices {
                showAnswer()
            }
        } else {
            // 2. 如果点击了错误的选项，立即结束
            selectedIndices.insert(index) // 将错误选项也加进去，以便标红
            showAnswer()
        }
    }

    private func updateButtonAppearance() {
        for button in optionButtons {
            if selectedIndices.contains(button.tag) {
                // 选中的正确选项显示为蓝色
                button.backgroundColor = funBtnColor.withAlphaComponent(highlightAlpha)
                button.layer.borderColor = funBtnColor.cgColor
                button.layer.borderWidth = 1
            } else {
                // 未选中的恢复默认
                button.backgroundColor = .clear
                button.layer.borderWidth = 0
            }
        }
    }
    
    func showAnswer() {
        guard !isAnswerShown else { return }
        isAnswerShown = true
        onAnswerRevealed?()

        // 关键修复：即使 correctIndicesString 为 nil，也继续执行，确保有视觉反馈
        let correctIndicesString = model.correctAnswerIndices ?? ""
        let correctIndices = Set(correctIndicesString.split(separator: ",").compactMap { Int(String($0)) })

        for button in optionButtons {
            button.isEnabled = false // 禁用所有按钮
            let tag = button.tag

            let isSelected = selectedIndices.contains(tag)
            let isCorrect = correctIndices.contains(tag)

            // 默认样式
            button.backgroundColor = .clear
            button.layer.borderWidth = 0

            if isCorrect {
                // 正确答案，用特殊颜色高亮
                button.backgroundColor = safeTipColor.withAlphaComponent(highlightAlpha)
                button.layer.borderColor = safeTipColor.cgColor
                button.layer.borderWidth = 2
            }

            if isSelected && !isCorrect {
                // 用户选择了错误的答案
                button.backgroundColor = reviewCellColor.withAlphaComponent(highlightAlpha)
                button.layer.borderColor = reviewCellColor.cgColor
                button.layer.borderWidth = 2
            } else if isSelected && isCorrect {
                // 用户选择了正确的答案，可以在正确高亮的基础上再加点标记，如果需要的话
                // 例如，添加一个对勾图标
            }
        }
    }
}
