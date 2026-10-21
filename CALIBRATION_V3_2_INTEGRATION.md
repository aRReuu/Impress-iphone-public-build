# Impress · 校准器既有实现记录与 V1.1 入口迁移契约

> 产品权威唯一为 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。本文件不再自称独立业务权威。唯一工作分支`feature/impress-duplex-loop-v1`；旧`feature/impress-vault-device-write-qa`与`feature/impress-v3-r04-2-build`只属历史，禁止据其施工。
> 2026-10-21 追加批准只读 B 方案周/月/年桌面 Widget（Small/Medium），归 NAV-05.w/SAFE-08.w；第三 Tab/既有校准数据/原周月年应用内图不变，不恢复闪卡首页周图。CAL-01～15 **新方案仍 DEFERRED**（计分公式、迁移、新图表、新提醒未解冻）；本次仅改文档。

## 1. 入口与状态保全

复用`aReuImpress-iPhone/VC/MainVCs/ImCalibrationVC/ImpressCalibrationViewController.swift`及既有Core/LocalStore。Tab必须展示真实既存数据，不建空白占位、不复制存储/计分器。已有设置入口可指向同一控制器/同一数据，通知点击和深链按目标身份，不依赖旧三Tab数组下标。首次进入不能重算过去或自动开启提醒。
沿用集中ImpressV3Appearance/ImpressV3Language、系统字号、三语言、App浅深色；入口调整不改变历史得分、目标快照、情绪或FSRS事件。普通闪卡复习不依赖校准完成。

笔记 Tab 一级目录树 UI-03.a 为独立导航改版，与校准器已存数据和通知完全隔离，不授权指标、分数、历史或提醒策略迁移。

## 2. V3.2 基线语义（兼容/回归记录，不是新方案获准）

现有五项：早睡/运动/饮食/情绪/自定义；情绪1～5或跳过、不计行为分。四项行为分别有+1完成/-1明确未完/0休息或不适用/未知未评估；旧完成门禁要求行为均处理且情绪记录或跳过。未知不当失败，全部豁免且无附加事件时数值可为nil。
现有额外+1/-1各最多一次，明确理由最多120字；旧净分为完成数减明确未完数，加减额外分；未知不发布分。唯一算法在`Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift`与`CalibrationCheckInCore.swift`，不在UI/通知复制。此记录不授权把旧算法冒称已实现CAL新要求。
新方案提出睡眠/运动/饮食/阅读四固定指标、自定义与情绪独立，但公式、迁移、分母、生效日期和交互未整体定案；**本轮不得把旧自定义偷偷改名为阅读、补算过去缺阅读为失败或重置历史。**

## 3. 时间、目标与历史

既有民用日期按设备Calendar/时区yyyy-MM-dd，不直接按UTC分组。已有周/月/年图和历史快照原样回归，不借Tab迁移重新设计图形/口径。旧周最近7日、月最近30日、年有效完成日月均及辅助趋势属于基线，不把旧图形视为新CAL-11获准方案。
`CalibrationGoals`当前标准与`CalibrationDayCheckIn.goalsSnapshot`每日快照保留；已有当日未完成目标变化只使变化项回待评估，其他项不动；完成日不重算。跨日/时区/DST仍须设备验证，未来规则另定。不得把工具得分宣传为人格/健康科学测量或从相关趋势推断因果。

## 4. 唯一数据和备份

闪卡/FSRS：`Documents/ImpressV3/ReviewV3.sqlite`；理解记录：`Application Support/ImpressV3/LearningEntry-v1.json`；提示词：既有UserDefaults库并归档prompts.json；校准：`Application Support/ImpressCalibration/checkins-v1.json`，由`ImpressCalibrationLocalStore` actor原子写/回读校验。Vault仍是外部源文件权威，生产写锁定。
只由`ImpressV3BackupCoordinator`统一备份，V1恢复不默默清掉已有校准数据；V2包含checkins，CRC/SHA/SQLite和JSON语义校验。恢复先预览/确认、保存恢复前镜像、下次冷启动替换；generation/Dirty防混时代，失败保护原数据。校准不另建iCloud/网络同步。普通ZIP未加密、本地Files写成功不等于服务器同步。
禁止向公共仓库提交真实checkins/数据库/笔记/Key/证书/用户截图。

## 5. 现有通知与路由回归

`UNUserNotificationCenterDelegate`保持唯一`ImpressV3NotificationCoordinator`；校准仍通过`ImpressCalibrationReminderCoordinator`与`impress.calibration.v1.`独立命名空间，不污染FSRS通知。用户主动授权、保留配额、关闭只取消校准、完成当天取消剩余当日提醒等现有语义须回归。
旧本地20:00/22:00与14日预排是基线设置记录，**不是本次重新开启、增加频次或强提醒的授权**。通知点击经现有RouteInbox进入新的校准Tab，不新建另一校准实例。权限拒绝/专注模式/后台限制/可清除通知如实处理，不承诺永久通知。

## 6. 测试与交付

保留`CalibrationScoreCoreTests`、`CalibrationCheckInCoreTests`、`ImpressCalibrationIntegrationTests`及WCDB备份回归；把旧“三Tab”导航断言改为“四Tab顺序/已有校准数据/通知正确路由”，不能删除评分/快照/备份测试。
新增计划`testFourTabsOpenExistingCalibrationWithoutRewritingScores`，当前NOT_RUN。在相同fixture下验证入口前后checkins字节/得分/目标快照/FSRS不因路由改变。iPhone13/三语言/字号/主题/通知/Files恢复按设备QA单独认证。
本轮仅定稿，不宣称新Tab已实现。后续同最终SHA完整CI/IPA证据；不改main/私库，不改原版AppIcon。旧缺1024图标/签名等门禁如实保留，不以自行生成图标绕过。校准新公式/阅读项迁移/新提醒继续DEFERRED，不阻塞已确认入口和主知识闭环。

## 2026-10-21 · 四 Tab 原生 UI 回归补记

主工程新建 `aReuImpress-iPhoneUITests`，以真实 App 启动、逐一点击四 Tab、截图和冷启动验证一级路由基础。这不会创建第二套校准器、修改既有历史评分或重新引入首页周图。校准器通知/深链与数据完整性仍需独立专项回归；未运行真实设备前不记 DEVICE_PASS，十八步双向知识 E2E 仍为 NOT_RUN。

## 7. 2026-10-21 · 只读桌面 Widget 接入说明

唯一需求权威 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md) §2.2；详细验收 [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md) §9。周＝最近7本地日含今天，月＝最近30本地日含今天，年＝本自然年；三个 WidgetKind，各支持 Small/Medium。采用 **B（评估行为/记录覆盖）**，净分仅次要展示。**用户于2026-10-21再次明确：桌面 Widget 必须沿用原 `ImpressCalibrationTrendChart` 二维坐标折线图，与校准器原 UI 保持同一坐标几何、灰色原始得分/蓝色均线、正零负刻度及缺失断线；原先状态点／日历矩阵视图作废。评估覆盖文字为 B 方案主信息；坐标中的得分辅助展示仍按旧算法，不推导新的 CAL 评分。绘制器必须共用，禁止主 App/Widget 各造一套看似相似的图。****`CalibrationDayCheckIn.isComplete` 可在全部豁免且 `netScore=nil` 时成立**；`trendRecords()` 的未完成记录得分缺失不可代表零评估；请从 `ImpressCalibrationLocalStore.history()` 的四行为＋`moodAssessed` 投影完整/部分/未评估状态。App 在原账本成功回读后向 `group.areu.impress` 原子写最小匿名统计快照，Widget 只读且失败空态，不另建分数权威、数据库、备份或写入许可。WidgetKit Extension/entitlement/provisioning、Timeline、深链同一校准 Tab、真实 iPhone13/IPA、三语言/主题及恢复均需实证，当前 **NOT_RUN**。CAL-01～15 新公式/目标迁移/新提醒照旧 DEFERRED。

## 8. 2026-10-21 · Widget 集成进度证据

此前本文件“本次仅改文档/尚无 Widget Target”的话属于 **2026-10-21 定稿当时**的历史状态。现以 `e6b77b2` / Actions Run `39586231838` 为新的可重复代码证据：Widget Extension、周/月/年三独立配置、Small/Medium 六套布局、最小隐私快照、主 App 校准保存后投影、Deep Link 路由代码已合入，Portable Core 99、原生 XCTest 185、XCUITest 7、Simulator Debug/Release、iPhoneOS ARM64 与内含 Widget.appex 的 unsigned IPA 全部构建测试 PASS。**但真机桌面、侧载 App Group 签名、完整 W12 深链及设备同步尚未验收**。CAL-01～15 新计分/提醒仍 DEFERRED。


## 9. 2026-10-21 · 同源 Cartesian 图表实际代码（新提交，完整 CI 待验）

`35dd7a0` 在唯一产品稿替换先前状态点／矩阵展示为同源二维折线图；`7c28b74` 抽取 App 原 `ImpressCalibrationTrendChart.draw` 内 CoreGraphics 几何为 `CalibrationCartesianTrendRenderer.draw`，原 App 实际调用同一绘图函数，WidgetKit 经 `CalibrationCartesianTrendRenderer.image` 绘制后嵌入 SwiftUI。`CalibrationWidgetProjection.cartesianPlot` 只使用既有只读快照的有效净分，周/月7日均线、年3月平滑依旧按原校准图口径，不对部分/无得分/全豁免虚构0；行为评估覆盖数据仍置于主标题。已添加纯 Core 缺失/正负分/月均/异常时区测试，**此处只登记 CODE_SUBMITTED；最终 CI/Widget 六尺寸设备截图/真实侧载未确认前不得标 TEST_PASS/DEVICE_PASS**。
