import UIKit

/// 标记问题视图 - 显示推荐的问题选项
class PresetQuestionsView: UIView {

    // MARK: - Properties
    /// 问题点击回调
    var onQuestionTapped: ((String) -> Void)?

    private let tableView = UITableView.init(frame: .zero, style: .plain)
    private var questions: [String] = []

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupViews() {
        backgroundColor = .clear
        isHidden = true // 默认隐藏

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = baseCellRowHeight
        tableView.register(PresetQuestionCell.self, forCellReuseIdentifier: PresetQuestionCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sectionFooterHeight = 1
        tableView.estimatedSectionFooterHeight = 1
        addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public Methods
    /// 更新标记问题列表
    func updateQuestions(_ questions: [String]) {
        // 如果没有问题时隐藏
        guard !questions.isEmpty else {
            isHidden = true
            return
        }

        self.questions = Array(questions.prefix(3))
        tableView.reloadData()
        isHidden = false
        animateIn()
    }

    /// 隐藏标记问题
    func hide() {
        isHidden = true
        questions.removeAll()
        tableView.reloadData()
    }

    // MARK: - Private Methods
    /// 依次淡入动画
    private func animateIn() {
        for (index, cell) in tableView.visibleCells.enumerated() {
            cell.alpha = 0
            UIView.animate(withDuration: 0.3, delay: Double(index) * 0.1, options: [], animations: {
                cell.alpha = 1
            }, completion: nil)
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension PresetQuestionsView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return questions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PresetQuestionCell.reuseIdentifier, for: indexPath) as? PresetQuestionCell else {
            return UITableViewCell()
        }
        cell.configure(with: questions[indexPath.section])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let question = questions[indexPath.section]
        onQuestionTapped?(question)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return defaultSpacing
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
}
