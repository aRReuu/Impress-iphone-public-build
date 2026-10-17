//
//  ImSettingsViewModel.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 10/5/25.
//

import UIKit
import Combine

class ImSettingsViewModel: ObservableObject {
    private let kIsAutoGenerateEnabled = "kIsAutoGenerateEnabled"
    private let kAutoGenerateIntervalHours = "kAutoGenerateIntervalHours"

    private let kSystemPrompt = "kSystemPrompt"
    private let kSystemPromptMigrated = "kSystemPromptMigrated"
    private let kIsMockDataEnabled = "kIsMockDataEnabled"
    private let kReminderMinutes = "kReminderMinutes"
    private let kIsWallpaperEnabled = "kIsWallpaperEnabled"

    // 费曼式系统提示词默认模板
    private let defaultSystemPrompt = """
    你是一个资深的全能专家，精通费曼学习法。你的任务是以费曼学习法的精神回答问题：

    1. **用引导方式回答我**：不能直接给正确答案,而是要精简(输出不要太长)和切中要害地给予引导式回答,另外是以智者以及老师的角度进行关键点拨内容输出,更主要的是引导我去更多地输出。

    2. **识别知识盲点**：主动指出回答中可能存在的模糊不清的地方，并澄清这些盲点。

    3. **通过比喻和类比深化理解**：用日常生活中熟悉的比喻、空间联想或其他非常规化的概念来解释复杂想法，让抽象概念变得具体可感。

    4. **从第一性原理出发**：追溯事物的根本原理，用最基本的概念来构建解释，而不是停留在表面现象。

    5. **结构化回答**：使用Markdown格式组织回答，使其层次清晰、易于阅读和复习。

    记住：好的解释不是让别人听懂，而是让自己能够用小学三年级的语言向一个孩子解释清楚。
    """

    @Published var isAutoGenerateEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isAutoGenerateEnabled, forKey: kIsAutoGenerateEnabled)
            if isAutoGenerateEnabled {
                ImAutoGenerator.shared.start(intervalHours: intervalHours)
            } else {
                ImAutoGenerator.shared.stop()
            }
            objectWillChange.send()
        }
    }

    @Published var intervalHours: CGFloat = 1.0 {
        didSet {
            UserDefaults.standard.set(intervalHours, forKey: kAutoGenerateIntervalHours)
            if isAutoGenerateEnabled {
                ImAutoGenerator.shared.start(intervalHours: intervalHours)
            }
            objectWillChange.send()
        }
    }



    @Published var isMockDataEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isMockDataEnabled, forKey: kIsMockDataEnabled)
            objectWillChange.send()
        }
    }

    @Published var reminderMinutes: Int = 30 {
        didSet {
            UserDefaults.standard.set(reminderMinutes, forKey: kReminderMinutes)
            objectWillChange.send()
        }
    }

    @Published var isWallpaperEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isWallpaperEnabled, forKey: kIsWallpaperEnabled)
            // 发送壁纸开关变化的通知
            NotificationCenter.default.post(name: .wallpaperSettingsChanged, object: nil, userInfo: ["isEnabled": isWallpaperEnabled])
            objectWillChange.send()
        }
    }

    var objectWillChange = PassthroughSubject<Void, Never>()

    @Published private(set) var systemPrompt: String = ""

    init() {
        self.systemPrompt = defaultSystemPrompt
        self.loadSettings()
    }

    private func loadSettings() {
        // TODO: 暂时不实现
//        isAutoGenerateEnabled = UserDefaults.standard.bool(forKey: kIsAutoGenerateEnabled)
//        intervalHours = UserDefaults.standard.object(forKey: kAutoGenerateIntervalHours) as? CGFloat ?? 1.0

        // 确保间隔在合理范围内
        if intervalHours < 1 {
            intervalHours = 1
        } else if intervalHours > 24 {
            intervalHours = 24
        }



        // 加载模拟数据开关设置，默认关闭
        isMockDataEnabled = UserDefaults.standard.bool(forKey: kIsMockDataEnabled)

        // 加载壁纸开关 설정，默认关闭
        isWallpaperEnabled = UserDefaults.standard.bool(forKey: kIsWallpaperEnabled)

        // 加载提醒间隔设置，默认30分钟
        let savedReminderMinutes = UserDefaults.standard.integer(forKey: kReminderMinutes)
        reminderMinutes = savedReminderMinutes > 0 ? savedReminderMinutes : 30

        // 初始化系统提示词（带数据迁移逻辑）
        migrateSystemPromptIfNeeded()
    }

    func setAutoGenerateEnabled(_ enabled: Bool) {
        isAutoGenerateEnabled = enabled
    }

    func setIntervalHours(_ hours: CGFloat) {
        var clampedHours = hours
        if clampedHours < 1 {
            clampedHours = 1
        } else if clampedHours > 24 {
            clampedHours = 24
        }
        intervalHours = clampedHours
    }



    func setReminderMinutes(_ minutes: Int) {
        var clampedMinutes = minutes
        if clampedMinutes < 10 {
            clampedMinutes = 10  // 最小10分钟
        } else if clampedMinutes > 1440 {
            clampedMinutes = 1440  // 最大24小时
        }
        reminderMinutes = clampedMinutes
    }

    func setSystemPrompt(_ prompt: String) {
        var validatedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        // 边界条件检查
        if validatedPrompt.isEmpty || validatedPrompt.count < 10 {
            // 如果为空或太短，使用默认费曼式提示词
            validatedPrompt = defaultSystemPrompt
        }

        // 检查是否包含潜在的安全风险内容
        let forbiddenPatterns = ["<script", "<iframe", "javascript:", "onload=", "onerror="]
        for pattern in forbiddenPatterns {
            if validatedPrompt.lowercased().contains(pattern) {
                // 如果检测到可疑内容，使用默认提示词
                validatedPrompt = defaultSystemPrompt
                break
            }
        }

        // 确保提示词不超过UserDefaults的合理大小限制（每个项目建议不超过1MB，这里限制为10KB）
        let maxLength = 10240
        if validatedPrompt.utf8.count > maxLength {
            validatedPrompt = String(validatedPrompt.prefix(maxLength / 2)) // 截取大约一半长度
        }

        // 更新系统提示词和持久化
        systemPrompt = validatedPrompt
        UserDefaults.standard.set(validatedPrompt, forKey: kSystemPrompt)
        objectWillChange.send()
    }

    func resetSystemPromptToDefault() {
        systemPrompt = defaultSystemPrompt
        UserDefaults.standard.set(defaultSystemPrompt, forKey: kSystemPrompt)
        objectWillChange.send()
    }

    /// 处理系统提示词的数据迁移，确保兼容性
    private func migrateSystemPromptIfNeeded() {
        let hasMigrated = UserDefaults.standard.bool(forKey: kSystemPromptMigrated)

        if hasMigrated {
            // 已经迁移过，直接加载已保存的系统提示词
            if let savedSystemPrompt = UserDefaults.standard.string(forKey: kSystemPrompt), !savedSystemPrompt.isEmpty {
                systemPrompt = savedSystemPrompt
            } else {
                // 如果没有保存的提示词，使用默认费曼式提示词
                systemPrompt = defaultSystemPrompt
            }
            return
        }

        // 首次迁移：检查是否已有用户自定义的系统提示词
        if let existingPrompt = UserDefaults.standard.string(forKey: kSystemPrompt), !existingPrompt.isEmpty {
            // 用户已有自定义提示词，保留原有的，应用边界检查
            setSystemPrompt(existingPrompt)
        } else {
            // 没有用户自定义提示词，使用默认费曼式提示词
            systemPrompt = defaultSystemPrompt
        }

        // 标记已迁移
        UserDefaults.standard.set(true, forKey: kSystemPromptMigrated)

        zcLog("系统提示词迁移完成")
    }
}
