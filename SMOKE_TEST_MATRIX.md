# Impress · 当前验收与完整冒烟矩阵

> **V1.1 当前测试规格与实际增量证据；历史 B0 阶段未执行新测试。** 需求权威为 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)，状态为 [REQUIREMENT_EXECUTION_MATRIX_20261020.md](REQUIREMENT_EXECUTION_MATRIX_20261020.md)。B0=`b7f5101187e37cffca87091bfd665eeaa94b9f59`，R0=`39443303363`，该历史 CI 已回读 success；不能据此认证新布局/复杂格式。服务层完整往返不是 UI E2E。

## 1. 证据记录契约

每次验收必须记录：Requirement ID/子项、场景、具体源码/入口、实际测试方法、环境/fixture、结果、精确 Git SHA、Actions Run ID与job、Simulator、连续UI E2E、物理设备、截图/日志定位、缺陷或具体外部阻塞。计划方法均为 NOT_RUN，不能当作已有测试。只有真正执行的层级可 TEST_PASS/E2E_PASS；代码已写只可 CODE_DONE；未执行 NOT_RUN；内部未实现 IN_PROGRESS，不以 DEVICE_BLOCKED 遮掩；已复现 FAIL；明确延期 DEFERRED。
以下“基线”统一指 B0/R0 的**历史证据定位**。表内未更新的“—/—”“NOT_RUN”是对应 ACCEPT 的完整逐项证明尚未登记，不否认后文列出的 Run #100 分层成功与新增真实 XCUITest；真实设备仍须验。不得只凭汇总 CI 将全部 ACCEPT 标为通过。

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

## 9. 2026-10-21 · B 方案 Widget 与新增闪卡冒烟（已有源码/部分测试，真实六布局与设备仍待验）

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


## 2026-10-21 · Chat 历史实际完成度复核

原执行矩阵的 `CHAT-03.a`、`CHAT-03.b` 写成 NOT_STARTED 不准确：`ImpressChatSessionHistoryViewController.buildHits(query:)` 已进行本地标题/草稿/来源/全文消息筛选并携带消息 ID；列表原生侧滑经确认后使用 `ReviewWCDBRepository.deleteChatSession`，删除会话的原消息与草稿清除、已执行回执保留、进行中状态拒删，CAS 防异步复活。`testHistorySearchRestoresMatchedSessionContext` 和 `testDeleteConversationPreservesAppliedReceiptsAndDoesNotResurrect` 已在 `355656de` / Run #100 的 185 项原生 XCTest 中通过。**更新为 CODE_DONE + NATIVE_TEST_PASS（针对这两个子项），但 ACCEPT-06 的真实 UI/冷启动/设备与异常并发边界仍待逐步补证；不得冒充全项 E2E_PASS。**


## 10. 2026-10-21 · F01～F13 故障注入证据映射（不把单测冒充全端 E2E）

**精确测试基线**：`355656de` / Run #100 原生 XCTest 185/185 PASS；`7c28b74` / Run #39600533287 第一次尝试原生 XCTest 185/185 PASS，但其连续 XCUITest 有一次在测试 Vault 阅读器进入时失败，**整个 Run 标记 FAILURE**。下面只追踪真正通过的原生/Core 单测范围，不能归并成 13/13 完整端侧崩溃注入通过；第二次执行与 Widget 新代码的独立结果须按 SHA/Attempt 记录。

| 场景 | 已存在且验证过的精确代码测试 | 证据边界／仍须补齐 |
| --- | --- | --- |
| F01 笔记成功、原卡 CAS 冲突 | `testDuplexPartialReceiptDoesNotReapplyWrittenQAFileOnCardConflict` | 真实 QA 文件回读与幂等已测；连续 UI 的单目标失败/重批准与进程注入仍需专项 |
| F02 笔记失败、原卡成功 | `testF02DeniedNoteWriteAndAppliedOriginalCardSurviveColdStart` | 原生 fixture/冷启动测试已有；真 File Provider 拒权/回执 UI 未认证 |
| F03 文件成功、回执丢失 | `testF03FileWrittenButReceiptMissingColdStartReconciliation`；Portable `F03InterruptedNoteReconciliationNeverReplaysStaleBytes` | 已核哈希/未重放；真进程在协调写和回执之间被强杀仍待注入 |
| F04 原卡已改、状态未记录 | `testF04CardCommittedButReceiptMissingAfterReopen`；Portable `F04InterruptedCardReconciliationUsesContentVersionNotReviewSchedule` | 已按内容版本回读；真强杀交错/服务进程中断仍待注入 |
| F05 重复确认／重试 | Portable `idempotentRetryIsNotASecondWrite`；`testDuplexPartialReceiptDoesNotReapplyWrittenQAFileOnCardConflict` | 同对象幂等成立；双目标 UI 重复快速点击及并发仍待验 |
| F06 执行／撤销时中断 | `testF06InterruptedApprovalBlocksDiscardAndForwardConfirmation`；Portable `F06DeselectCannotEraseInterruptedForwardApplication` | 未决状态不得丢弃；真实 `undoing` 强杀与冷启动 UI 需补 |
| F07 同文档两次批准 | `testTwoApprovedNoteRevisionsRemainIndependentAndUndoInReverseOrder` | 两个批准快照和逆序恢复已测；真机文件提供者异步冲突需补 |
| F08 旧撤销与新变更冲突 | `testExplicitQAUndoRestoresExactBOMCRLFBytesAndBlocksLaterConflict` | 原字节/后续变更冲突拒覆已测；实际 UI 撤销确认的 E2E 仍未全量完成 |
| F09 FSRS/内容交错 | `testDisposableVaultCardChatDuplexFullRoundTripAfterInterveningFSRS`；`testManualCardUndoCreatesNewContentVersionWithoutRescoring` | 保 cardID/调度与内容版本已测；真实 UI 返回原队列后完整复习边界待补 |
| F10 Vault 失权/移动/更改/跨源 | `testSameFileConflictsNeverOverwriteExternalEdit`；`testMissingSourceFailsClosedWithoutRecreatingFile`；`testVersionedNoteSourceLookupPreservesLegacyLinksAndSeparatesSameTitle` | 真实 iCloud/Files 撤权、跨 Vault/重名设备负向未验 |
| F11 ApprovedDraft 丢失 | `testF11MissingApprovedDraftDisablesNoteCommitFromApprovalUI` | 失快照拒绝操作已测；真实文件保护/恢复缺失的设备状态待验 |
| F12 旧数据库与备份恢复 | `testChatSessionReopensDraftAndPreservesHistoryInV3Backup`；`testV3BackupZIPRoundTripAndChecksumRejection`；`testColdRestoreFaultRollsBackCalibrationPromptsJournalAndSQLite` | WCDB/ZIP 基本恢复已测；多年代旧 JSON/老库及真机源回执全量迁移仍需证明 |
| F13 删除/发送/提案/备份并发 | `testDeleteConversationPreservesAppliedReceiptsAndDoesNotResurrect` | WCDB tombstone/CAS、留执行回执与禁止 `applying` 删除已测；正在真实网络流式发送和自动备份交错仍需 UI/设备注入 |

**结论**：F01～F13 均有某种原生/Portable 测试覆盖，但除子项测试外仍缺强杀故障窗口、系统授权变动和必要 UI 连续行为的统一同 SHA 证据。要继续补实际执行而不是再复制一组相同的 Service 单测。

## 11. 2026-10-22 · 同 SHA CI 全绿基线与 F06 逆向崩溃修复排队

- **已实际完成的旧 HEAD 证明**：`0f7bdd24c3023f3a03af5275c969682c6568ae43` / [GitHub Actions #39633907831](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39633907831) **SUCCESS**（2026-10-22 01:01 中国标准时间）。Portable Swift Core PASS、原生 XCTest **187/187 PASS**、真实进程 XCUITest **8/8 PASS**（包含真实 UI 的原卡批准后单目标安全撤销、两次用户确认、回执和冷启动）、Debug/Release Simulator PASS、unsigned iPhoneOS ARM64 PASS、嵌入原生 Widget.appex arm64 PASS、IPA ZIP 完整性 PASS。
- SHA 对应 unsigned 文件：`Impress-V3.1-P0P2-0f7bdd24c302-unsigned.ipa`，大小 **7,445,998 bytes**，文件 SHA-256 **`406ac69aedccc26e6e15837816e58ebb0dafcbe6bf13d3d3c95243769c232b19`**；[Actions Artifact #12364901665](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39633907831/artifacts/12364901665)。未签名、不含真实 iPhone13/Files/iCloud/Keychain/外部真实 API 的设备验收；不声称可无证书直接安装。
- **新增 F06 风险复核及排队修复（仅新代码，须等待下一 SHA CI 才可登记通过）**：之前已有的 `.undoing` 持久化逆向意图未进入「核查中断」，旧「安全撤销」反而仍可再次选择该中断对象。本批实现只读逆向核查，只有文件原 SHA 或 WCDB 恰好恢复到 `baseContentRevision+2` 且内容相同时记录 `.reverted`；源冲突、其他人合法编辑、缺字节、错误内容版本仍为 `.undoing`，不自动重播或猜成功。中断期间禁第二次逆向执行、正向确认与放弃；仅启用只读核验。新增 Portable/Core 正负向测试与原生 UI 锁门禁、内容真实落盘但回执未写且冷启动读取的负载测试，均为**新 SHA NOT_RUN**直到该次完整 CI。
- **交付边界不变**：18 步仍需补 UI 的继续 FSRS 评分、外部合法编辑冲突、端到端备份恢复与系统强杀；F01～F13 原生/Portable 单项不能冒充完整故障注入；W01～W15 尚缺 SpringBoard 六布局视觉/签名设备证据；ACCEPT-01～12 逐项仍有缺口；实体真机标记 DEVICE_BLOCKED，正式 Vault 写门禁永久 false。

## 2026-10-22 · UI 回归专项冒烟（U01–U12；未执行前 NOT_RUN）

| ID | 行为与完成标准 |
|---|---|
| U01 | 标准卡未揭示的超长 Markdown 题目准确三行：真实像素高度与文本片段一致，未揭示答案不可见；轻点截断题只进入全文，无评分 |
| U02 | 题干 Bold title2 大于正文 Regular body，富文本/粗体/列表/长中英文/系统大字号及答案滚动下均正确 |
| U03 | 长按题目与答案仅显示系统文本菜单，不存在自定义「摘录」按钮，不自动生成内容或上传 |
| U04 | 批量导入预览按钮与全局导航栏 tint、SF Symbol 和无障碍名称相同；保存/导入等页面不使用散落填充式导航色 |
| U05 | 新增卡片与批量导入的 Segmented Control 同尺寸、同语义色、同选中/未选中样式、深浅模式一致 |
| U06 | 笔记一级目录仅小 chevron，不有选中高亮，展开/折叠使用 UITableView 原生行插删动画；多目录、120分页、搜索与身份不回归 |
| U07 | 笔记详情内出现粗体大文档名，不显示源文件完整路径；原始 Vault/相对路径/SHA 强校验仍有效 |
| U08 | Chat 顶部圆形省略号直接展示 UIMenu，历史直达、设置子菜单及回执完整，无中转 VC，二次入口都可操作 |
| U09 | AI 服务连接、模型、隐私/任务列表的 icon 为统一动态灰色；颜色不被系统默认蓝覆盖，新增/刷新导航仍原生 |
| U10 | 无历史记录但 App Group 可用时，Widget 显示合法空坐标和 0/5，不把空态作负分 |
| U11 | Widget App Group 不存在、共享快照缺失/损坏/时区失效时主 App 明确诊断；无双向数据写回或假数 |
| U12 | 周/月/年 × Small/Medium 六布局真实 iPhone13 SpringBoard、Widget 装配、深链、AppGroup provisioning/签名与通知路由；未真机验证不得升级为 PASS |

以上条目与原 ACCEPT-01–12、W01–W15 同步，区别 CODE_DONE/NATIVE_TEST_PASS/XCUITEST_PASS/DEVICE_BLOCKED；本次增量新用例不得继承旧版全绿 Run。

### 2026-10-22 · GitHub 同 SHA 稳定基线与新增专项 UI 门禁

Run [#39648988015](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39648988015) / SHA `738a333d8a6ccd656117e0316bac6396ccf9f262` 已确认所有 Jobs SUCCESS：Native XCTest **191/191**、真实进程 XCUITest **8/8**，Portable Core、Debug/Release Simulator、unsigned arm64 + Widget Extension、ZIP 自检通过。IPA `Impress-V3.1-P0P2-738a333d8a6c-unsigned.ipa`（7,467,517 bytes，SHA256 `0323cf20e93104272f8cc5e72b32b0949878c0938b99d70aa4797f0bc5b6d628`）。**这是有效的自动化成功基线，但不是 U01–U12、18 步、F01–F13、真机 Widget 的整体验收成功。**

从该成功基线增量增加 `testNativeVaultOutlineFoldAndDocumentTitleWithoutPathBanner`：真实 UIKit 进入测试 Vault → 折叠状态核验 → 系统展开 → 子文件出现 → 折叠移除子文件 → 重新展开 → 阅读器显示实际文件标题而无完整路径栏 → 原生屏幕证据。新测试只有取得本次新 SHA 对应工作流通过才可记为 XCUITEST_PASS。

### 2026-10-22 · 最新笔记树真实 UI 成功基线 / FSRS 连续评分新门禁

- **确切 SHA** `36a494f3075ac3e3d4f8dcdaf40651024e078b4c` / [Actions #39654471424](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39654471424)：两个 Jobs **SUCCESS**；Portable Swift Core PASS，原生 XCTest **191/191 PASS**，真实进程 XCUITest **9/9 PASS**（新增 `testNativeVaultOutlineFoldAndDocumentTitleWithoutPathBanner` PASS），Debug/Release Simulator、unsigned iPhoneOS arm64 与嵌入 Widget.appex、IPA ZIP 完整性均 PASS。Artifact [#12372587204](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39654471424/artifacts/12372587204)。IPA `Impress-V3.1-P0P2-36a494f3075a-unsigned.ipa`，7,467,512 bytes，SHA256 `38823e5b8d3985c21e04dcba169bfc91135554b0fcf90bb112f94e79e7437c58`；仍为 **UNSIGNED**。
- **U06/U07：XCUITEST_PASS（本测试覆盖范围）**。实际合成测试 Vault 文件夹原生展开／折叠／重新展开、打开文档名、详情不含完整路径栏的可见路径；不等于 120 项分页、全部字号/语言及真机交互视觉已经完整验证。
- 下一轮 `P0-B` 连续可见 UI 扩展在该成功工作流结束后才进行：从本地历史讨论返回已经审批、已独立撤销的原卡，先验揭示锁，再明确揭示并使用真实卡片水平滑动执行 FSRS，冷启动确认不会立刻重复到期。**新增断言的 SOURCE/TEST_ONLY，此处不是 PASS；只有其自身新 SHA 的 CI 结果可认证。**
- 真正的完整 18 步 UI（备份 ZIP 恢复、外部并发合法修改冲突）、完整 F01–F13、iPhone 13 六布局 SpringBoard、主 App/Extension 同一有效 App Group 签名、Files/iCloud、Keychain/真实 provider HTTP 仍分别 NOT_RUN 或 DEVICE_BLOCKED。CAL-01–15/LOCAL-01–03 共18项 DEFERRED 不解冻；`productionWriteEnabled=false` 不变。

## 2026-10-22 · CAL-R01～R04 新验收范围（先施工，再按同 SHA 登记）

- CAL-R01：固定四行睡眠/运动/饮食/阅读，不存在“自定义”/“情绪”今日入口；未评估无净分，四项处理后停止当日提醒；Widget 今日 x/4。
- CAL-R02：旧 JSON 无 reading 字段解码、日期/来源历史保持，遗留 custom 从不暗换 reading；今天旧格式必须有独立的迁移审计和安全保存，旧完成状态历史不重算；Native 存储/备份回读测试。
- CAL-R03：Widget schema v2 防止五项旧缓存混读；未授权 App Group/未同步快照/无效时区快照分因；共享有效但无评分时仍展示合法空笛卡尔坐标。
- CAL-R04：同一净分源、同一绘制器周/月/年 × Small/Medium，实际 SpringBoard 截图、签名后双进程 App Group、刷新和深链；Simulator/Core PASS 不能代替 iPhone13 DEVICE_PASS。

这是增量验收要求而非已通过声明；ACCEPT-01～12、F01～13、18步、W01～W15 既有编号和生产 Vault 禁写门禁不变。

## 2026-10-22 · U13～U16 真机截图对应 UI 验收补充

- **U13 四方向提示（最新覆盖）**：揭示前无评分入口、仅先回忆文字；揭示后**没有任何四枚 chip/按钮/分立方向栏或空占位**，同一轻量状态文字显示「←困难/↑良好/→容易/↓重来」，仅通过真实滑动评分；辅助功能可读非按钮说明。
- **U14 中央拖动反馈（最新覆盖）**：四向分别仅一个在可见卡片中央出现的语义彩色标签（现有四级 token，对比度支持明暗模式），未达阈值预览可辨、取消回弹；长答案独立滚动不触发垂直 FSRS；必须实测只有一张卡一次提交。
- **U15 导航统一**：全局导航动作及 Modal/原 Markdown 旧顶部按钮在 System/Light/Dark 下使用动态 label 色，不再有系统蓝色顶栏图标；不影响底部 Tab 的蓝色选中语义，iPhone13 截图需要补充。
- **U16 Chat 输入样式**：和手机常用原生聊天输入交互一致的圆角输入容器，左 +、输入、右麦克风、黑白发送/停止；空时视觉 placeholder、输入/草稿恢复时消失，多行/键盘安全区动态适配。单测检查外观，真实 XCUITest 仍保留历史/授权/修订原业务完整路径。

已存在的 U01–U12、18步 E2E、W01–W15 和全部 F01～13 不删除；U13～U16 仅明确新增视觉验收条件，不能作为已有真机通过声明。

## 2026-10-22 · RDR-01～RDR-12 阅读专项（新增子测试，原 ACCEPT/F01～F13 不变）

| ID | 合成用例/断言 | 当前 |
|---|---|---|
| RDR-01 | 默认阅读、H1～H6、实际渲染非源码、无文件标题遮挡 | NOT_RUN |
| RDR-02 | 深层混合嵌套列表/长中文折行/任务/代码围栏标题不泄漏 | NOT_RUN |
| RDR-03 | 属性：顺序、字符串/日期/数字/布尔/列表/标签/链接/空值、折叠可访问 | NOT_RUN |
| RDR-04 | 非法/不支持 YAML 局部诊断、源码查看、BOM/CRLF 原字节与 SHA 不变 | NOT_RUN |
| RDR-05 | Mermaid 和 Markmap 真实离线 SVG/导图，局部异常隔离 | NOT_RUN |
| RDR-06 | Canvas/Excalidraw 文件及 Markdown 受限嵌入真实图形；缺资源安全降级 | NOT_RUN |
| RDR-07 | System/Light/Dark、大字、VoiceOver、长文连续滚动 | NOT_RUN |
| RDR-08 | 拖拽/平移/放大、节点/分支/章节来源范围与视觉一致 | NOT_RUN |
| RDR-09 | 图形/文字选材保留 Vault ID、相对路径、SHA 和真实 UTF8 范围 | NOT_RUN |
| RDR-10 | 引用循环、重名、符号链接、越界、撤权、文件版本变化、禁止远程请求 | NOT_RUN |
| RDR-11 | 真实进程：打开→选择→完整预览→确认进 Chat→返回→冷启恢复 | NOT_RUN |
| RDR-12 | 普通首屏耗时、重渲染、快切旧内容取消、内存与长文滚动 | NOT_RUN |

不得使用私人截图/笔记做公开 Fixtures。Core、Native XCTest、XCUITest、iPhone13 人工对照分开登记实际 PASS/FAIL/DEVICE_BLOCKED；未执行的一律不得改成 PASS。完成前必须确保同一最终源码 SHA 的 Actions PASS、IPA ZIP 完整性与 Widget 无回归。

### 2026-10-22 · RDR 测试断言加强及明确剩余边界（最终 SHA 新 CI 待登记）

本次代码新增 `ImpressFrontmatterReadingTests`、`ImpressVaultEmbedLocatorTests`、Properties/KaTeX/Mermaid/Markmap/Canvas/Excalidraw/一层 Markdown 嵌入进程测试。针对 **RDR-01/03/05/06**，不仅观察阅读器存在，还要求桥接报告实际图形成功/总数以及 KaTeX 节点计数；针对 **RDR-04/09/10**，原始 UTF8 范围、无效 YAML、源修订、路径穿越、外部 symlink、无效块定位及过深嵌入须负向拒绝。来源校验和 Chat 审批不依赖 HTML 文本逆向搜索。

以上仍是 **新测试源码**，未在精确最终 SHA 执行并拿到 GitHub Actions 证明前不得改写既有 RDR 表格中的 `NOT_RUN`；RDR-07/12 的大字号 VoiceOver/真实性能基线仍需单独证据。DEVICE_BLOCKED 不可伪装为 PASS。

## 2026-10-22 · 六张真机反馈：U17～U21 与 RDR-13～RDR-16 增量（均 NOT_RUN）

| ID | 必须以**当前构建 SHA**验证的断言 | 当前 |
|---|---|---|
| U17 | 标准/长问答卡揭示前后均不存在独立四向控件、无 `ratingGuide` 垂直空档；卡片顶部位置回收旧栏高度且未遮挡题干/揭示入口；截图比较实际 cardStack 高度 | NOT_RUN |
| U18 | Chat 键盘开合、候选栏、单行/多行/附件/停止态：placeholder 垂直居中，底边正确贴近键盘安全区，控件视觉紧凑且至少 44pt 热区，无多余浮动外框与跳动 | NOT_RUN |
| U19 | 「题干全文」及所有 UIKit 导航/Modal 顶部（含笔记/源码/编辑/Chat）动态中性色；System、Light、Dark、文字大字号；未误改 Tab/Segment 选中蓝 | NOT_RUN |
| U20 | 笔记一级页不存在 `UIRefreshControl`、下拉刷新触发/进度 UI；上下正常滑动不卡顿，前后台/页面返回有变化自动更新、没变化不 reload 整表 | NOT_RUN |
| U21 | iCloud/Provider 外部增删改名/嵌套目录与 Vault 更换/撤权：异步版本核验、局部 diff、取消旧请求、保留搜索/折叠/滚动位置；不显示另一 Vault 旧内容 | NOT_RUN |
| RDR-13 | 原生 `.excalidraw`、`.excalidraw.md`、**普通 `.md` 中有合法 `excalidraw-plugin` 元数据及有效 Drawing fence**（只读特征识别，单纯标签不触发），加压缩 JSON 与 `![[...]]`：必须出现真实图形；带曲线/箭头/嵌字/旋转/组的保真对照和缺件局部失败，不得显示 `Excalidraw Data` 充当图纸，且不得为源格式新增写权限 | NOT_RUN |
| RDR-14 | 中文 CSS 笔记：Props、H1/H2、嵌套有序与无序、代码、软硬换行、缩进导引线、列表项目含多段落；同一 fixture 下比对 Obsidian 参考截图结构与像素层级 | NOT_RUN |
| RDR-15 | Excalidraw 元素/组/区域、Canvas 节点、Mermaid、Markmap 的实际渲染成功率 + 源身份/SHA/真实范围 + 授权 Chat 往返；不可只凭桥接 `ready` 判定 | NOT_RUN |
| RDR-16 | iPhone13（记录安装 IPA 完整 SHA/Actions Run）与同字号、主题、宽度的 Obsidian 参考逐项对比：Properties 不遮挡、无重复标题、整页不出现巨型容器边框；设备缺失标 DEVICE_BLOCKED | NOT_RUN |

**旧用例替代**：2026-10-22 旧 U13 的“四枚可见 chip”以及旧 U14“仅黑白标签”断言均失效，必须修改自动化使其要求**没有四枚 chip**并验证四种语义颜色。禁止为了兼容旧断言重新增加显式控件。首要验证路径为当前真实安装 IPA、`ImVaultDocumentFormat.detect` 与对应渲染分支；截图不代表当前 HEAD 已运行，必须记录完整 SHA，才能在真实代码缺陷、旧安装包和资源装载故障间正确归因。保留原 U01–U16、RDR-01～RDR-12、18 步、ACCEPT-01～12、F01～F13 和 Widget 验收，所述新门禁不是 PASS。

## 2026-10-22 · G3 连续阅读器新增判定 RDR-17～RDR-22（当前全部 NOT_RUN）

| ID | 结构/来源/图形验收 | 当前 |
|---|---|---|
| RDR-17 | **唯一纵向滚动源**：Markdown 标题/类型化 Properties/正文/嵌入同一个 WK 文档随手指完整连贯滚动；无固定 header 与正文二次滚动、无整篇圆角暗色大卡片。长文首屏、属性折叠及 Dynamic Type 不跳变/不遮挡操作按钮。 | NOT_RUN |
| RDR-18 | 同名首 H1 与文件名**视觉只出现一个标题**但源 H1 仍可通过原 UTF8 锚点精确选材；不同名 H1 不得消失；Properties 折叠/展开、主题变化及返回 Chat 后滚动锚点/折叠状态按 Vault+SHA 保持。 | NOT_RUN |
| RDR-19 | 选中文字/章节后只能得到真实源 UTF8 范围（复杂中文、emoji、CRLF、BOM、WikiLink/Frontmatter 投影），JS DOM 不能反向猜源范围；未映射安全拒绝；完整预览及授权后进 Chat，变更 SHA 必须失败并重选。 | NOT_RUN |
| RDR-20 | 正常 `.md` + 明确合法 `excalidraw-plugin: parsed` 等插件 Frontmatter **及有效 Drawing fence**识别为只读 Excalidraw；仅 tag/虚假文字不得误判，分类随 SHA 重新判定；此类容器严禁 generic Markdown 写入（包括已授权 Debug QA），原生产门禁不变。 | NOT_RUN |
| RDR-21 | `![[合法.excalidraw.md]]`/`![[合法.canvas]]` 在 Markdown 原位输出真实有界图形预览，不泄漏压缩数据/插件文字；点击进入可缩放、选材的独立图形页，缺件/撤权/循环/网络引用仅局部安全失败，其他文本照常阅读。 | NOT_RUN |
| RDR-22 | 真实文档合成集：Excalidraw 手绘/曲线/笔触/箭头/多字形/旋转/图层/本地图片/frames A/B 对照官方导出；记录 bundle 体积、iPhone13 资源性能、许可证与离线审计，锁定视觉实现后重新跑图形/Chat 与完整回归。 | NOT_RUN |

**扩展门禁**：RDR-17～22 只是 RDR-01～16 的补充，不允许替代原 RDR-13/14 的可见画布/排版验收或原 U13～21 的 UI 需求。不使用用户私有截图或私人 Vault 文件作为公开 Fixture。原始二进制安装包必须附真实完整 SHA，未运行不写 PASS。

## 2026-10-23 · ChatGPT 全体验 / 系统附件 / Excalidraw 内容 / 校准 CLOSED 新验收子场景

这些只是补足 U18、CHAT-01/02/05/06、RDR-13/15/22、CAL-01～03 既有门禁的 **子项**；ACCEPT-01～12、U01～21、RDR-01～22、F01～13、Widget 矩阵不减项。全部当前 NOT_RUN；DEVICE_BLOCKED 仅给需要真机/有效签名的测试，不把源码缺口归设备阻塞。

| 子场景 | 验收观察点 | 当前状态 |
|---|---|---|
| U18.chat-layout | ChatGPT iPhone 基线同一设备/主题/字号：空会话、短长用户消息右侧气泡、AI 连续正文无「我/AI」标题/整行分色、消息操作栏、空白密度、标题/链接/代码/表格/公式、长文选择、历史恢复、滚动到底 | NOT_RUN |
| U18.chat-stream | 真正可 streaming Provider 的首 token/多段增量/停止/失败/重试/后台冷启，部分生成不得标 completed；不支持流式 Provider 诚实一次性显示 | NOT_RUN |
| U18.chat-composer | 输入1～多行/中文候选/英文/emoji/STT/附件/键盘/底部安全区/发送停止：文字与图标光学居中、touch >=44pt、无自动跳动/多余空白 | NOT_RUN |
| U18.system-attach | + 的相册/文件/拍照三入口；真实 iPhone13 相机权限、取消、不支持摄像头、Files iCloud security scope、选择后可预览/移除，未发送零网络、拒超额/不支持格式 | NOT_RUN |
| CHAT.media-provider | OpenAI Responses、Chat Completions、Anthropic、Gemini、其他兼容/自定义的能力矩阵：有图像/文件能力才转真实 payload；不支持时禁止误称已上传，保留免费测试门禁；取消/删除/冷启后附件仍安全 | NOT_RUN |
| RDR.content-fidelity | 同一合成 Excalidraw 的中文任务文字、bound text、箭头、曲线/手绘、frame/组、图片、前景/背景/透明度、旋转、缩放真实可读；与官方 SVG A/B，点击选元素后 Vault/SHA/ID 保真 | NOT_RUN |
| CAL.day-close | 四项中仍有 unrecorded 时可评估、section 可见；第四项成功保存后当天四项 section 整体消失，净分/覆盖率/二维图仍可见，额外修正及清除入口无法改闭账记录 | NOT_RUN |
| CAL.day-durability | store 直接传入不同 CLOSED 结果必须拒绝；重复保存幂等、后台重开、并发、多次触发、旧记录迁移、跨日和时区变化、备份恢复、Widget 投影/当日提醒不回归 | NOT_RUN |

所有 UI 截图须来自合成 Fixture 并附精确 SHA、设备、模式、失败证据；私人用户对比照片/真实 Vault 文件不得进入公开仓库。新旧两个 SHA 的截图不可混证；同最终 SHA 的 XCTest/XCUITest/IPA 需再次执行。
