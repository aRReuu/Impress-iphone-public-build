import UIKit
import WCDBSwift

protocol ImLLMDetailViewControllerDelegate: AnyObject {
    func didSaveModel(model: ImLLMModel)
}

class ImLLMDetailViewController: ImBaseViewController {
    
    // MARK: - Properties
    
    weak var delegate: ImLLMDetailViewControllerDelegate?
    private var model: ImLLMModel?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let nameTextField = UITextField()
    private let providerSegmentedControl = UISegmentedControl(items: [LLMProvider.gpt.rawValue, LLMProvider.gemini.rawValue, LLMProvider.openRouter.rawValue, LLMProvider.custom.rawValue])
    private let apiKeyTextField = UITextField()
    private let modelIdentifierTextField = UITextField()
    private let temperatureSlider = UISlider()
    private let temperatureValueLabel = UILabel()
    private let customBaseURLTextField = UITextField()

    // MARK: - Initialization
    
    init(model: ImLLMModel? = nil) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupNavigationBar()
        configureWithModel()
    }
    
    // MARK: - UI Setup
    
    private func setupViews() {
        view.backgroundColor = bgColor
        title = model == nil ? "添加新模型" : "编辑模型"

        // ScrollView and ContentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Form Fields
        setupTextField(nameTextField, placeholder: "模型名称 (e.g., My GPT-4)")
        setupSegmentedControl(providerSegmentedControl)
        setupTextField(apiKeyTextField, placeholder: "API Key", isSecure: true)
        setupTextField(modelIdentifierTextField, placeholder: "模型标识 (e.g., gpt-4-1106-preview)")
        setupTemperatureSlider(temperatureSlider)
        setupTextField(customBaseURLTextField, placeholder: "Base URL (可选, 用于自定义)")
        
        let stackView = UIStackView(arrangedSubviews: [
            createLabel("模型名称"), nameTextField,
            createLabel("模型名称"), nameTextField,
            createLabel("提供商"), providerSegmentedControl,
            createLabel("API Key"), apiKeyTextField,
            createLabel("模型标识"), modelIdentifierTextField,
            createLabel("Temperature"), temperatureSlider, temperatureValueLabel,
            createLabel("Base URL"), customBaseURLTextField
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveModelTapped))
    }

    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Configuration
    
    private func configureWithModel() {
        guard let model = model else {
            temperatureSlider.value = 0.7
            temperatureValueLabel.text = "0.7"
            providerSegmentedControl.selectedSegmentIndex = 0
            updateBaseURLVisibility()
            return
        }

        nameTextField.text = model.name
        apiKeyTextField.text = model.apiKey
        modelIdentifierTextField.text = model.modelIdentifier
        temperatureSlider.value = Float(model.temperature ?? 0.7)
        temperatureValueLabel.text = String(format: "%.2f", model.temperature ?? 0.7)
        customBaseURLTextField.text = model.customBaseURL

        switch model.providerType {
        case .gpt: providerSegmentedControl.selectedSegmentIndex = 0
        case .gemini: providerSegmentedControl.selectedSegmentIndex = 1
        case .openRouter: providerSegmentedControl.selectedSegmentIndex = 2
        case .custom: providerSegmentedControl.selectedSegmentIndex = 3
        case .none: providerSegmentedControl.selectedSegmentIndex = 0
        }
        updateBaseURLVisibility()
    }
    
    // MARK: - Actions
    
    @objc private func saveModelTapped() {
        guard let name = nameTextField.text, !name.isEmpty,
              let apiKey = apiKeyTextField.text, !apiKey.isEmpty,
              let modelIdentifier = modelIdentifierTextField.text, !modelIdentifier.isEmpty else {
            showAlert(message: "名称、API Key 和模型标识不能为空。")
            return
        }

//        if !isValidAPIKey(key: apiKey) {
//            showAlert(message: "API Key 格式不正确。请检查后重试。")
//            return
//        }

        if let baseURL = customBaseURLTextField.text, !baseURL.isEmpty, !isValidURL(urlString: baseURL) {
            showAlert(message: "Base URL 格式不正确。请填写有效的 URL。")
            return
        }
        
        let provider = providerSegmentedControl.titleForSegment(at: providerSegmentedControl.selectedSegmentIndex)!
        var modelToSave = self.model ?? ImLLMModel()
        modelToSave.name = name
        modelToSave.provider = provider
        modelToSave.apiKey = apiKey
        modelToSave.modelIdentifier = modelIdentifier
        modelToSave.temperature = Double(temperatureSlider.value)
        modelToSave.customBaseURL = customBaseURLTextField.text
        
        if modelToSave.identifier == nil {
            ImDBHandler.share.insertToDB(intoTable: ImDBTableType.llmModel.description, with: [modelToSave]) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.delegate?.didSaveModel(model: modelToSave)
                        self?.dismiss(animated: true, completion: nil)
                    case .failure(let error):
                        self?.showAlert(message: "保存新模型失败: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            ImDBHandler.share.updateToDB(table: ImDBTableType.llmModel.description,
                                         on: ImLLMModel.Properties.all,
                                         with: modelToSave,
                                         where: ImLLMModel.Properties.identifier == modelToSave.identifier!) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.delegate?.didSaveModel(model: modelToSave)
                        self?.dismiss(animated: true, completion: nil)
                    case .failure(let error):
                        self?.showAlert(message: "更新模型失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    @objc private func providerChanged(_ sender: UISegmentedControl) {
        updateBaseURLVisibility()
    }

    private func updateBaseURLVisibility() {
        let isCustom = providerSegmentedControl.selectedSegmentIndex == 3
        customBaseURLTextField.isHidden = !isCustom
        customBaseURLTextField.superview?.viewWithTag(100)?.isHidden = !isCustom // Hide the label as well
    }
    
    // MARK: - Helper Methods
    
    private func createLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .lightGray
        label.font = UIFont.systemFont(ofSize: 14)
        label.tag = 100
        return label
    }

    private func setupTextField(_ textField: UITextField, placeholder: String, isSecure: Bool = false) {
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.backgroundColor = tableViewBGColor
        textField.textColor = titleColor
        textField.isSecureTextEntry = isSecure
    }
    
    private func setupSegmentedControl(_ control: UISegmentedControl) {
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(providerChanged), for: .valueChanged)
    }

    private func setupTemperatureSlider(_ slider: UISlider) {
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        temperatureValueLabel.text = String(format: "%.2f", slider.value)
        temperatureValueLabel.textColor = titleColor
        temperatureValueLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        temperatureValueLabel.text = String(format: "%.2f", sender.value)
    }

    // MARK: - Validation
    
    private func isValidAPIKey(key: String) -> Bool {
        // A simple regex for API keys: checks for common prefixes and character sets.
        // This can be adjusted for specific provider requirements.
        let apiKeyRegex = "^(sk-|pk-|rk-|gk_)[a-zA-Z0-9-]{30,}$"
        let apiKeyTest = NSPredicate(format:"SELF MATCHES %@", apiKeyRegex)
        return apiKeyTest.evaluate(with: key)
    }

    private func isValidURL(urlString: String?) -> Bool {
        guard let urlString = urlString, !urlString.isEmpty else {
            return true // Optional field
        }
        if let url = URL(string: urlString) {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
