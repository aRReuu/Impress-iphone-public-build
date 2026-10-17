import UIKit

class PresetQuestionCell: UITableViewCell {

    static let reuseIdentifier = "PresetQuestionCell"

    private let questionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        questionLabel.textColor = titleColor
        questionLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        questionLabel.numberOfLines = 2
        questionLabel.textAlignment = .right
        questionLabel.lineBreakMode = .byTruncatingMiddle
        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(questionLabel)

        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            questionLabel.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: defaultSpacing * 2),
            questionLabel.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -defaultSpacing * 2),
            questionLabel.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func configure(with question: String) {
        questionLabel.text = question
    }
}
