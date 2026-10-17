//  ImSystemPromptViewController.swift
//  aReuImpress-iPhone
//
//  Created by Cline AI Assistant on 10/9/25.
//

import UIKit
import Combine

/// 系统提示词编辑控制器 - 费曼式学习法提示词编辑界面
/// 功能：编辑和管理AI助手的系统提示词，提供实时字符统计和验证
/// 特色：支持费曼学习法风格提示词、实时保存、长度限制
class ImSystemPromptViewController: ImBaseViewController, UIGestureRecognizerDelegate {

    // MARK: - Properties
    private var viewModel: ImSettingsViewModel!
    private var cancellables = Set<AnyCancellable>()

    // 键盘处理相关
    private var keyboardHeight: CGFloat = 0

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        return scrollView
    }()

    private let textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.returnKeyType = .default
        // 使用语义化背景色，确保暗黑模式支持
        textView.backgroundColor = secondaryBgColor
        textView.textColor = titleColor
        // 添加圆角和阴影效果
        textView.layer.cornerRadius = defaultSpacing / 2.0
        textView.layer.shadowColor = secondaryBgColor.cgColor
        textView.layer.shadowOpacity = 0.1
        textView.layer.shadowOffset = CGSize(width: 0, height: 2)
        textView.layer.shadowRadius = 4
        // 添加内边距
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        // 禁止水平滚动
        textView.showsHorizontalScrollIndicator = false
        textView.alwaysBounceHorizontal = false
        return textView
    }()

    private let characterCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = contentColor
        label.textAlignment = .right
        label.backgroundColor = .clear
        return label
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = placeholderColor
        label.numberOfLines = 0
        label.text = "提示词不能为空，请输入费曼学习法风格的系统提示词..."
        return label
    }()

    // MARK: - Initialization
    init(viewModel: ImSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTextView()
        setupBindings()
        setupNavigationBar()
        updateCharacterCount()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 移除所有键盘通知观察者，避免内存泄漏
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        // 移除所有键盘通知观察者，避免内存泄漏
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Setup
    /// 设置用户界面，优化视觉效果和布局
    private func setupUI() {
        title = "费曼式系统提示词"
        navigationItem.largeTitleDisplayMode = .never
        // 使用语义化背景色，确保暗黑模式支持
        view.backgroundColor = bgColor

        // 添加ScrollView容器
        view.addSubview(scrollView)
        scrollView.addSubview(textView)
        scrollView.addSubview(characterCountLabel)
        textView.addSubview(placeholderLabel)

        // 设置ScrollView约束，保持原有的top、leading、trailing
        // 创建底部分约束，准备用于键盘动态调整
        let scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -defaultSpacing * 4)
        scrollViewBottomConstraint.isActive = true

        // 保存底部分约束引用，用于键盘调整
//        self.bottomConstraint = scrollViewBottomConstraint

        // 设置ScrollView基础约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: defaultSpacing * 2),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: defaultSpacing * 2),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -defaultSpacing * 2),
            scrollViewBottomConstraint
        ])

        // 设置ScrollView内部组件约束
        let textViewTop = textView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor)
        let textViewLeading = textView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor)
        let textViewTrailing = textView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor)
        let textViewBottom = textView.bottomAnchor.constraint(equalTo: characterCountLabel.topAnchor, constant: -defaultSpacing)

        let characterCountLeading = characterCountLabel.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: defaultSpacing)
        let characterCountTrailing = characterCountLabel.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor)
        let characterCountBottom = characterCountLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        let characterCountHeight = characterCountLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: defaultSpacing * 1.5)

        NSLayoutConstraint.activate([
            textViewTop, textViewLeading, textViewTrailing, textViewBottom,
            characterCountLeading, characterCountTrailing, characterCountBottom, characterCountHeight
        ])

        // 设置ScrollView内容尺寸约束
        let contentWidth = scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        let contentHeight = scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)

        NSLayoutConstraint.activate([contentWidth, contentHeight])

        // 设置居中对齐（当内容小于ScrollView时）
        let centerX = scrollView.contentLayoutGuide.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor)
        let centerY = scrollView.contentLayoutGuide.centerYAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerYAnchor)
        centerY.priority = .defaultLow

        NSLayoutConstraint.activate([centerX, centerY])

        // 设置初始文本
        textView.text = viewModel.systemPrompt
        placeholderLabel.isHidden = !viewModel.systemPrompt.isEmpty
    }

    private func setupTextView() {
        textView.delegate = self
        setupKeyboardHandling()
    }

    private func setupBindings() {
        // 监听文本变化
        NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification, object: textView)
            .sink { [weak self] _ in
                self?.textDidChange()
            }
            .store(in: &cancellables)
    }

    /// 设置键盘处理通知
    private func setupKeyboardHandling() {
        // 添加键盘显示通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        // 添加键盘隐藏通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }

        keyboardHeight = keyboardFrame.height

        // 通过动画调整scrollView的contentInset
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.keyboardHeight, right: 0)
            self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }

        keyboardHeight = 0

        // 恢复原始contentInset
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = UIEdgeInsets.zero
            self.scrollView.scrollIndicatorInsets = UIEdgeInsets.zero
        }
    }
    


    /// 设置导航栏样式，优化视觉效果和用户体验
    private func setupNavigationBar() {
        // 重置按钮 - 使用语义化颜色
        let resetButton = UIBarButtonItem(image: UIImage(systemName: "arrow.counterclockwise"),
                                          style: .plain,
                                          target: self,
                                          action: #selector(resetToDefault))
        resetButton.tintColor = reviewCellColor
        resetButton.accessibilityLabel = "重置为默认提示词"
        //
        let saveButton = UIBarButtonItem(image: UIImage(systemName: "checkmark"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(savePrompt))
        saveButton.tintColor = safeTipColor
        saveButton.accessibilityLabel = "保存提示词"
        navigationItem.rightBarButtonItems = [saveButton, resetButton]
    }



    // MARK: - Actions
    @objc private func savePrompt() {
        let prompt = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if prompt.isEmpty {
            ImAlertController.alert(message: "提示词不能为空，请输入系统提示词。")
            return
        }

        if prompt.count < 10 {
            ImAlertController.alert(message: "提示词太短了，请输入更详细的系统提示词（至少10个字符）。")
            return
        }

        viewModel.setSystemPrompt(prompt)
        navigationController?.popViewController(animated: true)
    }

    @objc private func resetToDefault() {
        ImAlertController.alert(message: "确定要重置为默认的费曼式提示词吗？这将覆盖当前的修改。", buttons: alertDescription) { [weak self] result in
            if case .ok = result {
                self?.viewModel.resetSystemPromptToDefault()
                self?.textView.text = self?.viewModel.systemPrompt ?? ""
                self?.textDidChange()
            }
        }
    }

    // MARK: - Helper Methods
    private func textDidChange() {
        let text = textView.text ?? ""
        placeholderLabel.isHidden = !text.isEmpty
        updateCharacterCount()
    }

    private func updateCharacterCount() {
        let count = textView.text.count
        characterCountLabel.text = "\(count) 字符"
    }

}

// MARK: - UITextViewDelegate
extension ImSystemPromptViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        textDidChange()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        // 当textView开始编辑时，如果键盘高度不为0但contentInset尚未设置，则立刻设置contentInset
        if keyboardHeight > 0 && scrollView.contentInset.bottom == 0 {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
            scrollView.scrollIndicatorInsets = scrollView.contentInset
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // 检查字符长度限制（10KB）
        let currentText = textView.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: text)
        let maxLength = 10240 // 10KB

        if newText.utf8.count > maxLength {
            ImAlertController.alert(message: "提示词过长，请保持在\(maxLength)字节以内。")
            return false
        }

        return true
    }
}
