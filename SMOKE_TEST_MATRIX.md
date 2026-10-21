# Impress · 当前验收与完整冒烟矩阵

> **V1.1 开工前定稿，仅测试规格，未执行新测试。** 需求权威为 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)，状态为 [REQUIREMENT_EXECUTION_MATRIX_20261020.md](REQUIREMENT_EXECUTION_MATRIX_20261020.md)。B0=`b7f5101187e37cffca87091bfd665eeaa94b9f59`，R0=`39443303363`，该历史 CI 已回读 success；不能据此认证新布局/复杂格式。服务层完整往返不是 UI E2E。

## 1. 证据记录契约

每次验收必须记录：Requirement ID/子项、场景、具体源码/入口、实际测试方法、环境/fixture、结果、精确 Git SHA、Actions Run ID与job、Simulator、连续UI E2E、物理设备、截图/日志定位、缺陷或具体外部阻塞。计划方法均为 NOT_RUN，不能当作已有测试。只有真正执行的层级可 TEST_PASS/E2E_PASS；代码已写只可 CODE_DONE；未执行 NOT_RUN；内部未实现 IN_PROGRESS，不以 DEVICE_BLOCKED 遮掩；已复现 FAIL；明确延期 DEFERRED。
以下“基线”统一指 B0/R0 的**证据定位而非整项 PASS**；V1.1 的执行 SHA/Run 目前为“—/—”，Simulator/UI E2E为NOT_RUN，Device为DEVICE_BLOCKED（无物理设备与真实授权证据）。后续必须逐行替换为实际结果，不能只改总标题。

## 2. ACCEPT-01～12 逐项证据台账

源码缩写与 B-/P-测试定位按执行矩阵第2节解析为完整路径/方法。

| ID | Requirement | 入口 | 已有测试定位 | 新增/连续验证要求 | 基线 | V1.1 SHA/Run；Sim；E2E；Device |
| --- | --- | --- | --- | --- | --- | --- |
| ACCEPT-01 | LOOP-03/06, CHAT-06 | SELECT/DB | B-L；B-X | 真实UI选章、候选审核/删除/编辑/勾选，仅保存所选原卡/来源 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-02 | LOOP-03/04, SAFE-03 | REVIEW/NOTE/CORE | B-L | 双向导航，旧锚点/重名/跨Vault/移动/删除/撤权，不能猜来源 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-03 | CARD-01～06/08/13, UI-04 | REVIEW/CARD/OVERLAY | B-R；旧长文测试需更新 | P-R：题干三行/全文、答案触底、无题答标签、单对图标、中央评分，滚动选字不评分 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-04 | CARD-07/09/11 | REVIEW/EDITOR | B-E/B-F | 直接编辑/无改动/历史后回同卡同轮，取消不造版本 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-05 | CARD-09/10/12/14 | DB/REVIEW/EDITOR | B-E/B-F | 真实内容改变后旧答案失效；问答/选择/图片/解析/恢复保FSRS | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-06 | CHAT-02/03/04/10/11 | CHAT/DB | B-C/B-B | P-C：极简导航/输入、搜索命中/跨源恢复/安全删除/防复活/冷启动 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-07 | CHAT-05～08, AI-04～07 | CHAT/AI/SELECT/VAULT | B-M/B-A | P-M/P-V：二级配置、真实范围、复杂格式、依赖许可、首次说明≠发送许可 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-08 | LOOP-05/10/11, CHAT-09 | CHAT/Approval/Change | B-D | 指定完成AI回复形成可编辑建议，删除/修正/拒绝，笔记/原卡单选或双选真实Diff | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-09 | SAFE-02～05 | VAULT/DB | B-U | 明确批准→测试Markdown真实协调写/回读＋WCDB CAS；未选零改动，正式Vault拒绝 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-10 | LOOP-12/13, SAFE-07 | CORE/VAULT/DB/CHAT | B-D/B-U/B-B | 故障表F01～F13，逐对象事实、重复点击、崩溃窗口、重核查重批准 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-11 | LOOP-07～09 | NOTE/SourceImpactGate/DB | B-S/B-L | 源变更直接改原卡/明确不影响，无改动保存不确认，无关/排版低扰 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |
| ACCEPT-12 | LOOP-01～14, SAFE-07/11 | REVIEW/CHAT/NOTE/DB/BACKUP | B-X/B-B/B-U | P-X真实UI全程＋反向核查＋撤销＋冷启动＋ZIP恢复边界；同cardID/FSRS/历史 | B0/R0 | —/—；NOT_RUN；NOT_RUN；DEVICE_BLOCKED |

四Tab和复合阅读是额外必需交叉验收，归入原NAV/UI/CHAT/SAFE，不新增第86个主需求。仅十二项旧服务方法成功不能完成V1.1。

## 3. 真正 UI 连续往返（P0-B，计划）

用独立临时Vault、独立测试WCDB、固定合成模型响应与确定性数据；通过正常可见控件进行操作。Debug fixture/网络注入可以准备数据，但不能用“测试专用完成按钮”或直接调用服务跳过业务页面。CI没有XCUITest目标时补目标/资源/工作流，按真实限制记录，不把服务测试重命名为UI测试。

1. 启动App，验证四Tab并打开测试笔记。
2. 展开实际目录，选择一个可靠章节，预览选择范围。
3. 发起合成出题、进入候选池，编辑/删除候选并审核。
4. 明确保存一张原卡，核查持久cardID、来源及初始内容版本。
5. 从该原卡进入复习，验证三行题干及完整题干访问。
6. 打开真实对应来源，再返回同一复习位置。
7. 进入Chat，选择材料/模型并确认，保存一轮合成讨论。
8. 从指定已完成AI回复提出局部笔记及原卡修订，修改/删去部分建议。
9. 打开双目标完整Diff，切换单目标/双目标，验证取消无副作用。
10. 用户明确确认所选目标，授权只对应所见内容和版本。
11. 实际写测试Markdown与既有WCDB，不只存提案。
12. 从真实存储回读双方并展示逐目标回执。
13. 返回原卡/原队列继续FSRS，验证内容改变先重新揭示且评分恰好一次。
14. 模拟外部修改同一笔记相关章节，再回到来源核查入口。
15. 直接修改原卡或确认不影响，两条路径分别测试；无改动保存不算确认。
16. 安全撤销已应用修改，后续合法修改冲突必须阻止旧撤销。
17. 终止并重新启动App，不能通过重新初始化空数据库冒充恢复。
18. 核查原cardID、会话历史、提案/回执、内容版本、FSRS事件及队列恢复约束。

每一步保存可定位的运行证据。无网络/合成AI只证明该UI业务路径，不证明真实模型推理或Keychain；模拟器终止重开不证明真实Files Provider强杀后的全部行为。

## 4. 新界面与范围测试（计划，当前全部 NOT_RUN）

| 场景 | 必须观察的行为 |
| --- | --- |
| 笔记一级折叠树 | 目录树直接位于笔记 Tab，根文件/多层文件夹按层缩进，点击文件夹展开折叠；仅名称+必要 chevron，无装饰 icon、路径、副标题；点击文件才调用原 Vault 阅读器 |
| 笔记树搜索与授权 | 折叠子孙可搜索，匹配时展示祖先，清空恢复先前展开态；同名跨目录/跨 Vault 不串联；缓存/刷新/分页与撤权不误读、没有额外写入 |
| NAV 四Tab | 顺序正确，校准打开已有数据，通知/深链路由正确，无新分数/首页周图 |
| Chat 空态/未配置 | 无AI讨论标题、模型说明、顶部材料/提示词按钮；只保留功能列表/新建；草稿不因配置引导丢失 |
| Chat 输入 | 短输入紧凑，长输入增长后滚动，键盘跟随，附件按需出现，STT/发送/停止/失败重试可用 |
| Chat 介绍/同意 | 首次介绍只一次；更换服务商/扩大范围/源变更仍重新批准，取消零HTTP |
| Chat 历史搜索 | 全本地标题/消息/来源搜索、无结果/清空/返回位置、命中定位；跨来源不串材料 |
| Chat 删除 | 普通/当前/带提案/已应用/中断会话分别测；回执可达；发送/草稿回调不复活；备份保留范围告知 |
| 题干/答案 | 1/3/超3行、中英混排/emoji/H1/H2/大字号、短题无空占位；全文可达，答案触底 |
| 卡片控件 | 仅内部右上编辑/讨论；**揭示前隐藏、揭示后才可见、内容失效/换卡再隐藏，且无隐藏热区/焦点**；来源入口未丢；无底部重复按钮，无额外题答文字标签 |
| 新增卡片保存 | 右上苹果 `checkmark` 图标而非文字；与所有导航栏按钮 tint/背景一致，VoiceOver 仍为「保存」；校验、保存中禁用、防重复、失败重试、成功回读 | 
| 评分 | 中央可见紧凑单提示，四方向/转向/取消/阈值/重复手势；浏览点击/滚动/选字零评分 |
| 视觉 | iPhone13尺寸、简繁英、浅/深/跟随系统、DynamicType/SafeArea/VoiceOver；原生截图，不用HTML演示冒充 |

## 5. 复杂文档测试库（计划）

| 样例 | 展示、选择与安全条件 |
| --- | --- |
| Markdown结构 | ATX/Setext、跳级/重名/空标题、无标题开篇、嵌套列表引用、围栏长度/语言/缩进、伪标题 |
| Markdown字节 | BOM、LF/CRLF/CR/混合行尾、中文组合字符/emoji，原始字节与显示范围映射 |
| 富内容 | 代码/表格/公式/Callout/任务列表、WikiLink别名/heading/block、图片与本地附件 |
| 父子选择 | 父节包含子节到下一个同级/上级；多选去重；片段不错误截断表格/代码/公式 |
| 引用复合 | 笔记A嵌入B章节/块、再嵌绘图；每依赖版本/范围清单，普通链接不自动取全文 |
| Excalidraw | 原生与Obsidian封装、压缩/普通数据、中文/本地图片/嵌入、整图/框架/组/区域；预览绑定版本 |
| Canvas | 文字/文件/链接/分组、层叠/坐标/边/标签/subpath、选中/未选关系；平移缩放不写文件 |
| 导图 | Mermaid mindmap与Markmap分别测试，深分支/长中文/选择子树及必要父路径 |
| 模板/未知 | 模板语法/动态查询/未知插件保原文并局部告知；不运行模板、DataviewJS或插件代码 |
| 负向资源 | 缺件/循环/越界/符号链接/撤权/iCloud未下载/异常大图或压缩数据，有限资源与取消 |
| 兼容/权限 | 旧v1/v2/v3来源、旧Chat JSON、旧ZIP仍可读；扩展读取类型不放开Markdown写入器 |
| 图像理解 | 图能显示≠模型能理解；图像范围/提供商/能力单独确认，不自动收费/上传整图 |

每个已支持格式均执行“打开→正确显示→选择→实际材料预览→加入Chat→重开恢复”。登记选定依赖版本、许可、资源包、实际支持的语法；不能承诺所有社区插件都支持。全部远程资源默认阻断，JS桥不能读取任意本地文件或执行SQL。记录iPhone13首屏/峰值内存/长文滚动/图形缩放/取消/后台恢复，不填未经测试的性能数字。

## 6. P0-C 故障注入矩阵（所有成功事实必须保留）

| ID | 注入点 | 预期 |
| --- | --- | --- |
| F01 | 笔记成功、原卡CAS失败 | 笔记成功回执保留，不再写笔记；卡片重新核查明确批准 |
| F02 | 笔记失败、原卡成功 | 卡片成功事实保留，不回滚/重播卡片；笔记单独处理 |
| F03 | 文件已写、回执未持久化即终止 | 重启零自动重放；明确核对字节/快照后补事实，不猜成功 |
| F04 | WCDB内容已改、状态记录未完成 | 事务/内容版本事实可核实，不重复生成内容版本 |
| F05 | 重复确认/重试已应用提案 | 恰好一次应用；已应用对象禁止自动重放 |
| F06 | 执行或undoing时取消/强杀/重开Chat | 不能因取消勾选抹掉中断事实，不能自动正向/反向重播 |
| F07 | 同Markdown连续两次批准 | 不可变ApprovedDraft各自保留，历史Diff不读新草稿 |
| F08 | 旧撤销遇到后续合法文件/卡片修改 | 冲突拒覆盖；逆序合法撤销可回原字节 |
| F09 | 仅FSRS评分前进后改内容/撤销 | 使用最新调度CAS，保留评分，不制造虚假内容冲突 |
| F10 | 断Vault/移动/删除/换SHA/跨Vault同名 | 明确失败/重新定位核查，不从缓存写回、不按标题猜 |
| F11 | ApprovedDraft丢失/污染 | 安全失败，不用AI文本/SQLite元数据伪造原始字节 |
| F12 | 旧DB/旧Chat JSON/旧ZIP恢复 | 保留兼容数据，无自动重放，不混时代恢复 |
| F13 | 删除会话与发送/提案/备份并发 | 删除不复活、不级联删除已执行事实，恢复范围明确 |

失败对象只能在新鲜身份/版本/完整Diff核对和明确批准后继续，不把“重试”当永久授权。P0-D保留直接修订入口；无变化保存不承认不影响；仅排版/无关变化低扰动；重复/失效章节保守降级，不用旧笔记覆盖后来合法原卡。

## 7. 原专项编号保留（回归，不因改版删除）

DUPLEX-01正向双选、02生产拒写、03 Debug QA实际回读、04部分成功/幂等、05反向核查、06旧JSON/卡型兼容；P0-BYTE-01 BOM/CRLF局部修改、02混合换行不隐藏；P0-SOURCE-01返回重读；P0-RECEIPT-01连续提案收据保留。
UNDO-01原卡新restored版本、02后来内容冲突/仅FSRS变化不冲突、03 QA字节级逆向、04锁定/权限、05中断恢复；ANCHOR-01单一证据来源、02无关不扰、03失效/重复降级、04旧v1/v2兼容；SOURCE-SEG-01原卡核验后片段导航；AI-UPLOAD-01源变化禁旧发送、02进入/预览不上传。
必须保留回归：`testNewDraftAfterExternalEditCannotOverwriteOldPendingWork`、`testHistoricalDuplexPreviewKeepsOldDiffAfterLaterNoteDraft`、`testUnsentChatModelAndPromptSurviveColdStartAndLegacyJSON`；Portable `deselectionCannotErasePendingUndoAfterCrash`、`distantSmallEditsPreviewOnlyActualChangedHunks`、`separateInsertAndRemovalRemainVisible`。

## 8. 历史 A01～A20 与全业务回归

| ID | 当前追踪口径 |
| --- | --- |
| A01 | 旧三Tab被四Tab替代，路由仍回归 |
| A02 | 旧闪卡首页周图废止，校准器保留原页面；**新增 iPhone 桌面 Widget** 不属于闪卡首页周图 |
| A03 | 新增三类卡不重建当前队列 |
| A04 | 问答/选择/图片编辑、独立解析、无改动/取消 |
| A05 | 内容历史恢复为新版本，保中间版本 |
| A06 | LearningEntry旧记录兼容/编辑历史 |
| A07 | FSRS评分与内容修改交错 |
| A08 | Vault授权/目录/搜索/复杂阅读/草稿/原字节保真 |
| A09 | Provider/模型搜索/提示词/Keychain/GLM/自定义兼容 |
| A10 | 多会话/材料/草稿/历史/删除恢复边界 |
| A11 | 失败/停止/重试/无自动收费回退 |
| A12 | 普通总结与具体修改提案分离 |
| A13 | 原卡→Chat→测试笔记Diff/实际写/回读 |
| A14 | 取消/冲突/幂等/不重放 |
| A15 | 原有多卡/新建冲突需核查，不把全库重构变本轮前置 |
| A16 | 笔记/Chat共用候选池与入库 |
| A17 | 来源变化提示与原卡核查 |
| A18 | 同一备份体系，Chat/提案/回执与旧ZIP兼容 |
| A19 | 三语言/主题/字号/SafeArea/STT/键盘/真实设备 |
| A20 | 无秘密泄漏/生产锁定/真实分层证据 |

备份回归包含CRC/SHA/SQLite integrity、并发变更generation、Dirty标记、恢复前镜像、SQLite/WAL与JSON一致性、冷启动前完成恢复。普通ZIP不加密；原始Markdown批准快照仅本机保护目录，不进普通ZIP；恢复后缺快照禁撤销，不伪装异机字节恢复成功。
STT回归包含三独立识别locale、模型可用/显式下载/麦克风权限、UTF-16范围、取消/过期编辑、final-only提交及单次回调，不新增伪语音聊天。通知回归含FSRS/校准命名空间隔离、权限、点击路由、不因新Tab新增催促策略。
最终构建须同一SHA：全部Portable Core/原生XCTest、实际UI测试或明确运行限制、Debug/Release Simulator、ARM64、无XCTest污染的IPA、ZIP完整性及SHA-256。物理iPhone13/真实HTTP/Keychain/Files/iCloud各自留证据；正式Vault一直锁定，原版图标/签名限制如实保留。文档提交不产生新的QA安装包。

## 2026-10-21 · 最新执行证据补录（原18步/F01～13规格不变）

已新增 `aReuImpress-iPhoneUITests/ImpressV11NavigationUITests.swift` 作为真实进程内的 XCUITest（实际四 Tab 点击、冷启动和截图），并纳入 Xcode Scheme；**它不实现本文件第3节的18步闭环**，后者仍为 NOT_RUN。F03/F04 新增 `ImDuplexInterruptedRecovery` 和 Approval 界面“核查中断”入口，可对上次 `applying` 状态回读 SHA/内容版本并禁止未经核查重试；尚未完成真实断点强杀注入，F01～F13 不得整体 TEST_PASS。

Excalidraw compressed-json/有限 PNG/JPEG 的源码和测试已提交，但全图形/范围/附件仍有实现缺口。接受度台账 ACCEPT-01～12 需逐项填最新 SHA、Run ID、真实 XCUITest/截图及设备限制；不允许用旧成功 Run `39489025745` 证明新增功能。

## 9. 2026-10-21 · B 方案 Widget 与新增闪卡冒烟（设计已定，全部 NOT_RUN）

新验收基于 `NAV-05.w/SAFE-08.w/CARD-08.a/UI-01.a`，不插入原有十八步 E2E 中途、不删 F01～F13。每项需记录准确代码 SHA、Actions Run、真实 XCTest/XCUITest 名、Widget Preview/Simulator、iPhone13 桌面截图、签名 entitlement/安装结果、失败原因；静态设计/Swift Core 通过不能冒充桌面 E2E。

| ID | 必须验证 |
| --- | --- |
| W01 | 周 Small：今日明确评估 x/5；原 App 同源二维七日得分与7日均线、X日期/Y正零负刻度；未记录断线，全豁免不得画零 |
| W02 | 周 Medium：与 App 同源二维七日坐标图及日标签，完整/部分天数为主；和 Small 仅信息密度差异，不替换图表 |
| W03 | 月 Small：最近30日本地日的二维坐标折线及7日均线；有明确评估天数为主，跨月不断档、缺失断线 |
| W04 | 月 Medium：与 App 相同二维30日坐标系统，首/中/末日 X 标签、正零负 Y 刻度；文字列出完整/部分评估，不采用30日矩阵 |
| W05 | 年 Small：本年12个月二维月均每日得分与3月均线；年内有明确评估天数为主，未来月份必须断线、不当0 |
| W06 | 年 Medium：与 App 相同12月二维坐标图（灰色月均/蓝色3月均线），另附评估覆盖与有效自然日信息 |
| W07 | 无数据、零评估、仅有1～4项、情绪跳过、四行为明确未完成、全部评估、全豁免净分 nil、仅附加分理由等状态均准确 |
| W08 | `CalibrationDayCheckIn` 的原始评估/目标快照与 FSRS 不改变；不能仅通过 `trendRecords()` 的净分 null 猜是否记录 |
| W09 | App Group 原子最小快照；没有用户笔记/Key/Vault/个人目标文字；Widget 仅读，文件损坏/无权限安全空态 |
| W10 | App 保存完成后的快照刷新、冷启动/备份恢复后从原 Store 重新投影；共享文件不成为第二备份 |
| W11 | 连续7/30日本地日期、闰日/DST/时区/跨年、本年未来月份；Timeline 刷新受系统控制不声称即时 |
| W12 | 周/月/年三 Widget 分别深链到同一校准 Tab 对应周期；冷启动、已有会话、通知不互扰 |
| W13 | 六布局同源 Cartesian/CoreGraphics 渲染与 App 固定输入/尺寸几何对比：轴线、Y零线、刻度、灰蓝双折线、空点、孤点和字体颜色一致；简繁英、Light/Dark/System、Dynamic Type、VoiceOver、Small 无溢出 |
| W14 | Widget Extension target 在 Debug/Release/iPhoneOS/最终 IPA 实际存在；主 App 和 Extension entitlement/Bundle ID/provisioning、真实设备添加及侧载限制有证据 |
| W15 | 没有新计分/旧历史迁移/新通知策略；CAL 新规则仍 DEFERRED，原十八步/F01～F13 与备份无回归 |

另需真实测试闪卡：未揭示两图标隐藏且不能聚焦，揭示后出现，进入编辑/讨论保持 cardID/队列，内容实际变化揭示失效再隐藏，换卡恢复初态，所有显隐不评分；新增页 `checkmark` 与统一导航样式、可访问性、表单校验/保存防重复/失败回读必须过 XCUITest。旧 `testQuickEditAndVerifiedSourceVisibleBeforeAnswerWithoutScoring` 的「揭示前可见」部分已被新需求取代，改断言而非删来源安全测试。

### e6b77b2 运行证据登记（2026-10-21，不篡改 W01～W15 原始验收标准）

Run `39586231838` / SHA `e6b77b2430c9f3ca6568d4471c3a1e327cfd054a`：**Portable Core 99 PASS / XCTest 185 PASS / XCUITest 7 PASS / Debug+Release Simulator PASS / unsigned iPhoneOS ARM64 与 Widget.appex 二进制、IPA ZIP/哈希 PASS**。W07/W08/W11 的纯状态/日期/隐私子测试获得 **CORE_PASS（仅 Core 证据）**；W14 的 unsigned 打包子步骤 **BUILD_PASS**，不等于真机可签名运行；W01～W06 原生 Widget 视觉/添加、W09 签名授权、W10 设备重启恢复、W12 真实系统路由及 W15 真机隐私 **NOT_RUN**。原 18 步 UI E2E 目前的连续测试覆盖双目标建议/审批/重启但不覆盖全部中断回滚和手动撤销，仍是 **PARTIAL_E2E_PASS**，不得标注完整 E2E_PASS。见 [Actions Run #39586231838](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39586231838)。

产物 `Impress-V3.1-P0P2-e6b77b2430c9-unsigned.ipa`，SHA256 `b7b1174a969103b1ec1dbf16b29aa8f7cf52b8d54a7b10d1146fcbbafba90b57`。它是 **UNSIGNED**，必须独立合法签名并验证 Widget Extension 与 `group.areu.impress` 相同有效 entitlement 才能宣称设备可用。
