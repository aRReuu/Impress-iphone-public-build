# Impress V3.2 — 校准器统一业务与集成权威

> 当前开发权威：公开仓库 aRReuu/Impress-iphone-public-build / feature/impress-v3-r04-2-build。原 feature/impress-calibration-v01 为校准器来源，源 HEAD c16c4a605c5b6018861ff1691d6e6abbba0d8901。本文不授予私有仓库写权限。

## 1. 产品边界与架构
Impress 是低摩擦个人成长工具：一方面通过闪卡、主动回忆与 FSRS-6 进行结构化认知巩固；另一方面通过极少量行为指标进行自我观察与校准。它不是心理诊断工具、临床健康评价、无穷累计积分游戏，也不是完整任务管理器。情绪与睡眠、运动、饮食可能相互影响，不能从本工具的趋势推断因果。
三个原生一级 Tab（顺序固定）：闪卡、校准、设置。「笔记」不是一级 Tab，而是闪卡首页导航栏右侧的显式独立文字按钮，与「卡片集」独立并列；点击进入原有 Obsidian Vault 只读笔记控制器，返回仍在闪卡导航栈内。校准入口为 ImCalibrationVC/ImpressCalibrationViewController.swift；外观复用 ImpressV3Appearance、UIKit Dynamic Type、系统 Light/Dark，图表为带 X/Y 刻度的周/月/年二维折线。既有闪卡四向滑动、FSRS 状态、Obsidian Vault 只读入口及设置不得回退。设置新增 App 内 System/Light/Dark 三态与简体中文/繁体中文/英文语言选项；界面文案与外观 token 集中配置。该变化仅影响呈现，不修改历史校准得分、目标快照、情绪或复习事件。

## 2. 五项指标与完成标准
| 指标 | 记录 | 是否计分 |
| --- | --- | --- |
| 早睡 | +1 完成、-1 明确未完成、0 计划休息/不适用、未知 未评估 | 是 |
| 运动 | 同上 | 是 |
| 饮食 | 同上 | 是 |
| 情绪 | 1–5 等级或明确跳过 | 否 |
| 自定义 | 用户设定的第五项行为；+1/-1/0/未知 | 是 |

四项行为标准为用户可编辑文本；情绪只有观察价值，不因低落而扣分。必须四项行为均明确处理，且情绪已记录或跳过，才认定该日完成。未评估不自动转为未完成；计划休息不是惩罚。若四项均豁免且无附加计分事件，当日可视为已评估完成，但数值仍为无数据（nil）。

## 3. 手工修正与评分唯一权威
每日额外 +1 最多一次、-1 最多一次；保存时要求明确理由（最多 120 字），可修改、清除。仅用于计划外且未计入既有四项的独立行为。语义重复必须由用户判断确认：代码通过固定独立 eventKey 和数量限制防止形式重复，但无法自动理解两个自然语言行为是否实质相同。
每日净分 = 完成数 - 明确未完成数 + 额外加分 - 额外减分。未知时不发布数值。来源权威仅有 Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift 和 CalibrationCheckInCore.swift；禁止在 UIKit、通知或持久化层复制另一套计分器。FSRS-6 的复习评分是完全不同的业务，不与校准分合并。

## 4. 时间序列与可比性
X 为用户当前日历/时区对应的 yyyy-MM-dd 民用日期，不能直接按 UTC 时间戳对日期分组。周视图展示最近 7 个日历日，月视图最近 30 日，年视图展示 12 个月的**已完成日净分平均值**；不使用无限累加分。辅助趋势是之前 7 个日历日内已有有效得分的均值，缺失日期与未完成日期保留断线，不填 0。年视图原控制器另绘制 3 个月均值辅助线，不应冒称 7 日移动平均。
更改行为数量、标准或任务难度会降低原始净分的跨期可比性。不得把绝对净分高低宣传为整体成长、情绪或健康的科学测量。

## 5. 目标与历史快照
CalibrationGoals（实际类型 CalibrationGoals）保存四项当前标准；CalibrationDayCheckIn.goalsSnapshot 保存每天的历史标准。未完成的当天更改目标时，**仅有变化的指标**恢复未知/待评估，不触动已确认的其它指标。已完成日期的目标快照保持不变。跨日/时区变化以现场 Calendar.current 的民用日期归属，记录的是日期字符串而不是 GMT 秒数；跨时区日期漂移和 DST 仍应真机校验。

## 6. 本地数据与权限边界
- 闪卡：Documents/ImpressV3/ReviewV3.sqlite（WCDB/FSRS-6；旧 impressdata.db 不参与启动）。
- 理解历史：Application Support/ImpressV3/LearningEntry-v1.json。
- 可编辑提示词：UserDefaults 中 ImpressV3LocalPromptLibraryV1，归档为 prompts.json。
- 校准器：Application Support/ImpressCalibration/checkins-v1.json，版本 1，原子写入、读后解码校验；存储适配器为 ImpressCalibrationLocalStore actor。
- Obsidian Vault：外部 Files Provider 授权目录是原始文档权威；生产写入锁定，不属于校准器、闪卡数据库或自动备份。
项目/测试均不得提交任何真实 checkins、数据库、密钥、证书、Vault 原件或私人图像；仓库中只存合成测试夹具。

## 7. 单一系统通知委托
UNUserNotificationCenterDelegate 仅由 ImpressV3NotificationCoordinator 管理；校准通过 ImpressCalibrationReminderCoordinator 调度，命名空间 impress.calibration.v1.，与 FSRS 通知独立。需要用户主动授权，默认候选时间每天本地 20:00 与 22:00，预排未来 14 天的非重复通知；保留 FSRS 可用通知配额，不能承诺永久提醒。
校准页自身显示未评估数量。完成当天五项时，取消当天剩余校准通知（保留未来日期）；用户关闭时仅取消校准命名空间。通知点击通过共享委托与 ImpressCalibrationNotificationRouteInbox 导向现有校准 Tab。权限拒绝、系统专注模式、iOS 后台限制及系统通知可被清除的特性必须如实告知。

## 8. V3 统一备份与恢复
原 R04.2 ZIP V1 含 ReviewV3.sqlite、LearningEntry-v1.json、prompts.json 与 manifest.json。V3.2 ZIP V2 另加 checkins-v1.json，采用 ZIP stored entries、CRC32、SHA-256、SQLite integrity_check 与校准 JSON 语义解码。V1 解包恢复时**保留设备已存在的校准历史**，不默默清空。V2 恢复前预览卡片、复习历史、理解历史和校准天数，必须经用户确认；先快照回滚副本、暂存解包并于下次冷启动替换，失败尽力恢复 SQLite、提示词、理解历史及校准。
备份只由 V3 BackupCoordinator 统一负责，校准器不另造 iCloud 或网络同步业务。校准文件在落盘并解码校验之后标记 V3 数据变化；iCloud Drive 仅向用户明确授权的文件夹尝试复制，文件提供者写入成功不等于服务器同步完成。**当前 ZIP 没有密码加密**，即使具备 SHA/CRC 完整性验证也不等于保密；不要将该文件视作端到端加密资料。

## 9. 测试、CI 与验收事实
CalibrationScoreCoreTests、CalibrationCheckInCoreTests 覆盖五项完成门禁、情绪跳过、休息、额外计分、历史快照、周/月/年、民用日期与提醒规划。ImpressCalibrationIntegrationTests 覆盖三个一级 Tab、路由及临时 JSON 持久化；ReviewWCDBRepositoryTests 增加 V1/V2 归档与校准记录验证。
历史可复验的 R04.2 基线：commit e9eb5e92679907ab95c6aff615d5a6719b69eb46，对应 https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39054675238：78/78 UIKit XCTest 通过，但该运行早于 V3.2 合并。**V3.2 最终 HEAD 的完整 CI 和物理 iPhone 13 尚待重新验收**；不能引用旧 CI 当作新版本 PASS。

## 10. 后续修改、公开来源与发布门禁
当前公有 feature/impress-v3-r04-2-build 是唯一可修改权威；不修改公有 main、私有仓库或校准器来源分支。独立维护校准纯 Core、唯一 LocalStore、唯一 BackupCoordinator 与现存通知委托；不得重复实现业务层。
发布阻断：原版 icon_1024.png 仍未由授权源提供；禁止生成替代。未签名、使用七个原版 iPhone Icon 的测试 IPA 只能列为 INCOMPLETE 候选；需要真实 iPhone 13 设备验证通知、iCloud 授权、恢复与 UI 后才能批准正式发布。
