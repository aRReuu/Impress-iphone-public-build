# Impress 校准器 V0.2 · 五指标及后续合并约束

工作分支：feature/impress-calibration-v01（仅公有仓库）；其他分支及私有仓库不改动。

## 五项评估

1. 早睡：完成 +1、明确未完成 -1、休息/不适用 0。
2. 运动：同上。
3. 饮食：同上。
4. 情绪：记录 1–5 等级或主动跳过。负面情绪不自动扣分，情绪仅是观察指标。
5. 自定义：用户自己定义一项行为标准，完成 +1、未完成 -1、休息/不适用 0。

四项行为目标可修改；已经保存的某天保留当时目标快照，不能因之后修改目标而重写历史。五项必须全部明确评估，才能结束当天待处理状态。尚未记录不是未完成，不自动扣分。额外加分/减分各最多一次，必须写具体原因，不能对同一行为重复计分。

## 曲线口径

每日净分 = 已完成行为数 − 明确未完成行为数 + 手工额外调整。
周：最近 7 个日历日，月：最近 30 个日历日，年：按月计算每日净分的均值，不累计总分。第二条线为最近 7 个日历日中有完整评估的得分均值。无记录或部分记录为数据缺口，不作 0 分处理。任务数量/难度变化会改变净分可比性；不将分数等同于个人价值或整体成长水平。

## 通知的系统边界

iOS 不支持永久无法划除的系统通知，也不能保证无限期后台重复推送，必须尊重通知许可与专注模式。因此实现为：
- App 内持续展示当天五项待评估数量。
- 用户主动授权后，每天 20:00 和 22:00 预排一次性本地提醒，滚动安排未来 14 天，最多 28 条，并为既有 FSRS 通知保留容量。
- 当天五项完成后取消当日后续提醒，同时保留未来日期提醒；用户禁用时只移除校准器命名空间的通知。
- 没有打开 App 补充排程时，14 天后预排提醒会耗尽；不承诺无限期主动推送。
- 仍由原有 UNUserNotificationCenterDelegate 统一接收；新增校准器通知 ID 命名空间，不覆盖闪卡提醒及冷启动入口。

## 独立数据与页面

Foundation 纯逻辑：CalibrationScoreCore.swift、CalibrationCheckInCore.swift。
本地历史：ImpressCalibrationLocalStore.swift，位于 App 私有 Application Support，使用原子 JSON 和独立版本文件，不接入原 FSRS WCDB、Obsidian 或云端。
控制器：ImpressCalibrationViewController.swift，使用现有 UIKit/ImpressV3Appearance 风格；此分支在现有闪卡/笔记/设置三 Tab 基础上增设第二个「校准」Tab，不删除原入口。
通知适配：ImpressCalibrationReminderCoordinator.swift；最小增量修改 SceneDelegate、原通知委托、TabBar、Xcode 项目 Source 列表。

## 验收和发布约束

Swift Core 测试涵盖加减分、缺失记录、五项完成门禁、历史快照、情绪跳过、额外修正及周/月/年时间归集。
模拟器测试涵盖独立 Tab、通知路由和临时存储；必须以 CI 真正完成为准。
现有 R04.2 发布安全门禁缺少公有源中的原始 icon_1024.png，已发现该门禁在 iOS 编译前失败。不可用生成图标替代或绕过门禁发布；独立 calibration-native-validation.yml 只负责代码编译及 XCTest，不能视为 IPA 发布批准。
真实 iPhone 13 的通知投递/跳转、深浅色与交互仍需设备验收。

## 与其他模型并行及后续合并

其他模型仍可能更新 feature/impress-v3-r04-2-build。此分支不会自动 merge、rebase、reset、push 到其他分支。
以后合并时按目标分支最新 HEAD 做冲突对照，重点处理 ImTabBarViewController.swift、SceneDelegate.swift、ImpressV3NotificationCoordinator.swift 和 project.pbxproj；必须以逐点整合代替覆盖整文件。
禁止未经单独许可合并 private main、公有 main，或迁移任何私密文档、真实个人日志、证书与密钥。
