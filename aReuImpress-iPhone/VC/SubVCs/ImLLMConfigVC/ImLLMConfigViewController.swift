import UIKit
import Combine
import WCDBSwift

class ImLLMConfigViewController: ImBaseViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - UI Components
    
    private let tableView = UITableView.init(frame: .zero, style: .insetGrouped)
    
    // MARK: - Properties
    
    private var models: [ImLLMModel] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupNavigationBar()
        loadModels()
    }
    
    // MARK: - UI Setup
    
    private func setupViews() {
        view.backgroundColor = bgColor
        title = "大模型配置"
        
        // TableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.register(ImLLMTableViewCell.self, forCellReuseIdentifier: "ImLLMTableViewCell")
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addModelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissModal))
    }
    
    @objc private func dismissModal() {
        // 总是发送通知，即使没有默认模型也要发送nil通知
        let defaultModel = models.first(where: { $0.isDefault == true })
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "LLMModelDidChange"), object: defaultModel)
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Data Handling
    
    private func loadModels() {
        ImDBHandler.share.queryFromDB(table: ImDBTableType.llmModel.description, cls: ImLLMModel.self) { [weak self] result in
            switch result {
            case .success(let models):
                self?.models = models
                self?.tableView.reloadData()
            case .failure(let error):
                print("Failed to load LLM models: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func addModelTapped() {
        let detailVC = ImLLMDetailViewController()
        detailVC.delegate = self
        let navVC = ImNavigationViewController(rootViewController: detailVC)
        present(navVC, animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ImLLMTableViewCell", for: indexPath) as? ImLLMTableViewCell else {
            return UITableViewCell()
        }
        let model = models[indexPath.row]
        cell.configure(with: model)
        
        // Handle the switch toggle
        cell.onSwitchToggle = { [weak self] isOn in
            guard let self = self else { return }
            self.setDefaultModel(at: indexPath.row)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedModel = models[indexPath.row]
        let detailVC = ImLLMDetailViewController(model: selectedModel)
        detailVC.delegate = self
        let navVC = ImNavigationViewController(rootViewController: detailVC)
        present(navVC, animated: true, completion: nil)
    }
    
    private func setDefaultModel(at index: Int) {
        let selectedModel = models[index]

        // 如果当前模型已经是默认的，则取消选中
        if selectedModel.isDefault == true {
            // 取消所有模型的默认状态
            for i in 0..<models.count {
                models[i].isDefault = false
            }

            // 发送nil通知，表示没有默认模型
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "LLMModelDidChange"), object: nil)
        } else {
            // 设置选中的模型为默认
            for i in 0..<models.count {
                models[i].isDefault = (i == index)
            }

            // 发送新默认模型的通知
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "LLMModelDidChange"), object: selectedModel)
        }

        // 更新UI和数据库
        tableView.reloadData()
        updateDefaultModelInDatabase()
    }

    private func updateDefaultModelInDatabase() {
        for model in models {
            guard let modelId = model.identifier else { continue }
            ImDBHandler.share.updateToDB(table: ImDBTableType.llmModel.description,
                                         on: ImLLMModel.Properties.all,
                                         with: model,
                                         where: ImLLMModel.Properties.identifier == modelId) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print("Failed to update model \(model.name ?? ""): \(error)")
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let modelToDelete = models[indexPath.row]

            // 检查是否为默认模型，如果是则阻止删除
            if modelToDelete.isDefault == true {
                let alert = UIAlertController(title: "无法删除", message: "当前选中的默认模型不能直接删除，请先选择其他模型为默认，或取消所有模型的选中状态。", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
                return
            }

            guard let modelId = modelToDelete.identifier else { return }

            // 从数据库删除
            ImDBHandler.share.deleteFromTable(table: ImDBTableType.llmModel.description, where: ImLLMModel.Properties.identifier == modelId) { [weak self] result in
                switch result {
                case .success:
                    // 从数组中移除
                    self?.models.remove(at: indexPath.row)

                    // 刷新表格视图
                    tableView.deleteRows(at: [indexPath], with: .automatic)

                case .failure(let error):
                    print("Failed to delete LLM model: \(error.localizedDescription)")
                    // 显示错误提示
                    let alert = UIAlertController(title: "删除失败", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

// MARK: - ImLLMDetailViewControllerDelegate

extension ImLLMConfigViewController: ImLLMDetailViewControllerDelegate {
    func didSaveModel(model: ImLLMModel) {
        // 重新加载模型数据，并在完成后发送通知
        ImDBHandler.share.queryFromDB(table: ImDBTableType.llmModel.description, cls: ImLLMModel.self) { [weak self] result in
            switch result {
            case .success(let models):
                self?.models = models
                self?.tableView.reloadData()

                // 发送通知，通知聊天界面模型已更新
                let defaultModel = models.first(where: { $0.isDefault == true })
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "LLMModelDidChange"), object: defaultModel)

            case .failure(let error):
                print("Failed to reload LLM models after save: \(error.localizedDescription)")
                // 即使加载失败也尝试重新加载一次
                self?.loadModels()
            }
        }
    }
}
