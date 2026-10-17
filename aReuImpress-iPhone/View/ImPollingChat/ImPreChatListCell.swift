//
//  ImPreChatListCell.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 7/28/25.
//

import UIKit

/// 预设聊天列表单元格
class ImPreChatListCell: UITableViewCell {
    static let reuseIdentifier = "ImPreChatListCell"

    // MARK: - UI Components
    let questionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = titleColor
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = contentColor
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    let sourceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = contentColor.withAlphaComponent(buttonIconAlpha - 0.2)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    let statusIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = titleColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        return imageView
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let topStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .top
        return stack
    }()

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupViews() {
        // fix 切勿设置背景色,让系统自定义适配白天暗夜模式
//        backgroundColor = tableViewBGColor
        selectionStyle = .default

        contentView.addSubview(stackView)

        // Top row: status indicator + question label
        topStack.addArrangedSubview(statusIndicator)
        topStack.addArrangedSubview(questionLabel)

        stackView.addArrangedSubview(topStack)
        stackView.addArrangedSubview(contentLabel)
        stackView.addArrangedSubview(sourceLabel)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: defaultSpacing),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: defaultSpacing),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -defaultSpacing),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -defaultSpacing)
        ])
    }

    // MARK: - Configuration
    func configure(with preChat: ImPreChatModel) {
        questionLabel.text = preChat.question ?? "无问题"
        contentLabel.text = preChat.content ?? ""

        if let source = preChat.questionSource, !source.isEmpty {
            sourceLabel.text = "来源：\(source)"
            sourceLabel.isHidden = false
        } else {
            sourceLabel.isHidden = true
        }

        // Set status indicator based on whether chat has been started
        let isChated = preChat.isChated ?? false
        if isChated {
            statusIndicator.image = UIImage(systemName: "message.fill")
            statusIndicator.tintColor = .systemGreen
        } else {
            statusIndicator.image = UIImage(systemName: "circle")
            statusIndicator.tintColor = .systemGray
        }
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        questionLabel.text = nil
        contentLabel.text = nil
        sourceLabel.text = nil
        sourceLabel.isHidden = false
        statusIndicator.image = nil
    }
}
