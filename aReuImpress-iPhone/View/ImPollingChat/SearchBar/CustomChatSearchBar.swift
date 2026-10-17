//  CustomChatSearchBar.swift
//  aReuImpress-iPhone
//
//  Custom chat search bar view with search input and pagination buttons
//  Simplified design to avoid constraint conflicts
//

import UIKit

class CustomChatSearchBar: UIView {

    // MARK: - Callbacks
    var onSearchTextChanged: ((String) -> Void)?
    var onSearchButtonPressed: ((String) -> Void)?
    var onClearButtonPressed: (() -> Void)?
    var onNavigateUp: (() -> Void)?
    var onNavigateDown: (() -> Void)?

    // MARK: - UI Components
    private let backgroundView = UIView()
    private let textField = UITextField()
    private let clearButton = UIButton(type: .system)
    private let upButton = UIButton(type: .system)
    private let downButton = UIButton(type: .system)

    // MARK: - Constants
    private let viewHeight: CGFloat = 64
    private let buttonSize: CGFloat = 44
    private let textFieldMargin: CGFloat = defaultSpacing
    private let buttonSpacing: CGFloat = 8

    // MARK: - Properties
    private var isSearchActive = false

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupActions()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
        setupActions()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: viewHeight)
    }

    // MARK: - Setup Methods
    private func setupViews() {
        // Ensure this view can receive input
        self.isUserInteractionEnabled = true

        // Background view
        backgroundView.backgroundColor = tableViewBGColor
        backgroundView.layer.cornerRadius = defaultSpacing
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.borderColor = subTitleColor.cgColor
        backgroundView.layer.shadowColor = shadowColor.cgColor
        backgroundView.layer.shadowOpacity = 0.05
        backgroundView.layer.shadowRadius = 2
        backgroundView.layer.shadowOffset = CGSize(width: 0, height: 1)

        // Text field
        textField.placeholder = "搜索对话内容..."
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.textColor = titleColor
        textField.tintColor = funBtnColor
        textField.borderStyle = .none
        textField.returnKeyType = .search
        textField.clearButtonMode = .never
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        // Clear button
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = subTitleColor
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)

        // Navigation buttons
        upButton.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        upButton.tintColor = funBtnColor
        upButton.addTarget(self, action: #selector(upButtonTapped), for: .touchUpInside)

        downButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        downButton.tintColor = funBtnColor
        downButton.addTarget(self, action: #selector(downButtonTapped), for: .touchUpInside)

        // Set button dimensions (separate method to avoid conflicts)
        [clearButton, upButton, downButton].forEach { button in
            button.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
        }

        // Add subviews in correct order
        addSubview(backgroundView)
        backgroundView.addSubview(textField)
        backgroundView.addSubview(clearButton)
        addSubview(upButton)
        addSubview(downButton)

        // Delegate
        textField.delegate = self

        // Initial state
        updateButtonStates()
    }

    private func setupConstraints() {
        [backgroundView, textField, clearButton, upButton, downButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Background view fills parent with margins
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: defaultSpacing),
            backgroundView.trailingAnchor.constraint(equalTo: upButton.leadingAnchor, constant: -defaultSpacing),
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.heightAnchor.constraint(equalToConstant: defaultSpacing * 3),

            // Text field inside background
            textField.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: textFieldMargin),
            textField.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),

            // Clear button
            clearButton.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -4),
            clearButton.widthAnchor.constraint(equalToConstant: buttonSize),
            clearButton.heightAnchor.constraint(equalToConstant: buttonSize),

            // Up button (left side)
            upButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            upButton.trailingAnchor.constraint(equalTo: downButton.leadingAnchor, constant: -buttonSpacing),
            upButton.widthAnchor.constraint(equalToConstant: buttonSize),
            upButton.heightAnchor.constraint(equalToConstant: buttonSize),

            // Down button (right side)
            downButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            downButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -defaultSpacing),
            downButton.widthAnchor.constraint(equalToConstant: buttonSize),
            downButton.heightAnchor.constraint(equalToConstant: buttonSize),
        ])
    }

    private func setupActions() {
        updateClearButtonVisibility()
        updateButtonStates()
    }

    // MARK: - Public Methods
    func setSearchText(_ text: String) {
        textField.text = text
        updateClearButtonVisibility()
    }

    func getSearchText() -> String {
        return textField.text ?? ""
    }

    func setNavigationEnabled(upEnabled: Bool, downEnabled: Bool) {
        upButton.isEnabled = upEnabled
        downButton.isEnabled = downEnabled

        upButton.alpha = upEnabled ? 1.0 : 0.3
        downButton.alpha = downEnabled ? 1.0 : 0.3
    }

    func setResultCount(_ count: Int, current: Int) {
        setNavigationEnabled(upEnabled: count > 1, downEnabled: count > 0 && current < count)
    }

    func showKeyboard() {
        textField.becomeFirstResponder()
    }

    func hideKeyboard() {
        textField.resignFirstResponder()
    }

    func clearSearch() {
        textField.text = ""
        updateClearButtonVisibility()
        onClearButtonPressed?()
    }

    // MARK: - Private Methods
    private func updateClearButtonVisibility() {
        let hasText = !(textField.text?.isEmpty ?? true)
        clearButton.isHidden = !hasText
    }

    private func updateButtonStates() {
        // Default state - navigation buttons disabled
        setNavigationEnabled(upEnabled: false, downEnabled: false)
    }

    @objc private func textFieldDidChange() {
        updateClearButtonVisibility()
        onSearchTextChanged?(textField.text ?? "")
    }

    @objc private func clearButtonTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        clearSearch()
    }

    @objc private func upButtonTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onNavigateUp?()
    }

    @objc private func downButtonTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onNavigateDown?()
    }
}

// MARK: - UITextFieldDelegate
extension CustomChatSearchBar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let searchText = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !searchText.isEmpty {
            onSearchButtonPressed?(searchText)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        isSearchActive = true
        updateClearButtonVisibility()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        isSearchActive = false
    }
}
