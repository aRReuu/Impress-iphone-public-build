import UIKit

class ImLLMTableViewCell: ImBaseTableViewCell {
    
    // MARK: - UI Components
    
    private let nameLabel = UILabel()
    private let providerLabel = UILabel()
    private let modelIdentifierLabel = UILabel()
    let defaultSwitch = UISwitch()
    
    var onSwitchToggle: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupViews() {
        // Name Label
        backgroundColor = tableViewBGColor
        nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        nameLabel.textColor = titleColor
        
        // Provider Label
        providerLabel.font = UIFont.systemFont(ofSize: 14)
        providerLabel.textColor = .lightGray
        
        // Model Identifier Label
        modelIdentifierLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        modelIdentifierLabel.textColor = .systemGray
        
        // Default Switch
        defaultSwitch.onTintColor = .systemGreen
        defaultSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        
        // Stack View
        let verticalStack = UIStackView(arrangedSubviews: [nameLabel, providerLabel, modelIdentifierLabel])
        verticalStack.axis = .vertical
        verticalStack.spacing = 4
        verticalStack.alignment = .leading
        
        let horizontalStack = UIStackView(arrangedSubviews: [verticalStack, defaultSwitch])
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 12
        horizontalStack.alignment = .center
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(horizontalStack)
        
        NSLayoutConstraint.activate([
            horizontalStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            horizontalStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            horizontalStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            horizontalStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    @objc private func switchValueChanged() {
        onSwitchToggle?(defaultSwitch.isOn)
    }
    
    // MARK: - Configuration
    
    func configure(with model: ImLLMModel) {
        nameLabel.text = model.name ?? "未命名"
        providerLabel.text = "提供商: \(model.provider ?? "未知")"
        modelIdentifierLabel.text = model.modelIdentifier ?? "未指定"
        defaultSwitch.isOn = model.isDefault ?? false
    }
}
