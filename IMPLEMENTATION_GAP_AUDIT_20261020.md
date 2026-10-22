# Impress · V1.1 开工前差距与防走偏审计

> 本次只更新现有稿件。唯一产品权威：[PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。代码基线B0=`b7f5101187e37cffca87091bfd665eeaa94b9f59`，完整成功Run `39443303363`。旧Run/旧截图/测试名称不证明新要求通过；本文件不是完工声明。

## 1. 本次定稿消除的冲突

| 旧问题 | 已写入当前稿件的替代规则 | 对代码的影响 |
| --- | --- | --- |
| 产品/README/校准稿并存三Tab、旧分支和首页周图 | 四Tab；唯一feature/impress-duplex-loop-v1；首页周图不恢复 | 需改导航/路由及旧测试，未施工 |
| 题干要求首页全文滚动与最新三行限制冲突 | 三行题干＋点击读全文，答案完整滚动 | 需改布局/测试，非截断数据 |
| 重复编辑、底部大按钮、题答难分、评分提示太小 | 卡内右上双图标、字重/细线、可见中心紧凑反馈 | 需原生视觉/手势验证 |
| Chat配置/说明常驻占阅读空间 | 二级功能列表＋独立新建，紧凑输入，首次说明和发送许可分开 | 不删除功能/授权 |
| 历史页仅展示列表 | 全本地搜索/定位、明确删除与回执保全、防复活 | 需DAO/UI/备份并发验证 |
| 只换Markdown样式就声称兼容 | 结构范围/来源映射＋成熟引擎＋Excalidraw/Canvas/导图适配 | 不复制整个Obsidian、不新建笔记库 |
| 基线含实现却仍写“只有提案结构、没有回执” | 区分已存在能力与真正剩余断层 | 复用，禁止重复开发 |

## 2. 既有基础必须保留，不能当成未开发

已存在源码/测试定位：WCDB内容CAS和FSRS分离；内容历史；同源多会话/草稿；统一双目标预览/逐对象状态；ImVaultPrivateStore不可变ApprovedDraft；QA协调写/备份/回读；安全撤销；v1/v2/v3来源；ImpressSourceImpactCardRevisionGate直接修订/不影响；逐摘录发送门禁、失败后换服务商再授权、长历史窗口告知。
方法定位见矩阵B-R～B-X与SMOKE。B0的CI成功不能替代新增交互验收，也不能说这些基础从未实现。矩阵旧42/25/18记录保留供追溯，本轮没有冒充逐条重跑或整体E2E通过。

## 3. 当前真实施工缺口与门禁

| 范围 | 剩余工作 | 判定 |
| --- | --- | --- |
| 笔记一级目录树（UI-03.a） | 现有扁平列表、装饰 icon、路径副标题和二级文件夹主浏览需替换成原生树；保留全量搜索、身份、授权、分页和笔记详情 | 新增已定规格，必须完成原生代码与测试，不能仅写文档 |
| NAV/CARD/CHAT新布局 | 四Tab、三行题干、右上双图标、中央反馈、极简Chat | 新规格尚未实施，不是外部阻塞 |
| Chat历史 | 全本地搜索、命中定位、跨源激活及带回执 tombstone 删除代码已存在；Run #100 原生 XCTest 已覆盖对应方法 | 剩余真实 UI 滑动确认、搜索定位、冷启动/备份及并发设备证据；不得重新开发既有功能 |
| 结构选材 | 现有按#扫描不等于AST/范围；不能仅全文，需父子去重/无标题/复合来源 | 需解析与权限一致验证 |
| 复杂文档 | 不能仅升级CSS；枚举/身份/资源/引擎/材料/回读全链 | Excalidraw/Canvas/Mermaid/Markmap本轮范围，不静默延期 |
| P0-A | 指定完成AI回复生成可审核具体建议，不只预填原文的手工编辑器 | 优先补业务断层，复用提案/CAS |
| P0-B | 服务层完整往返不等于连续原生UI | 补真实XCUITest及合成响应，限制具体记录 |
| P0-C | 双向部分成功、写后收据前中断、DB变后状态未存、删除并发 | SMOKE F01～F13故障注入 |
| P0-D | 已有反向直接修订不重写；排版/无关低扰、重复/失效、no-op/FSRS交错 | 补最终证据与边界 |
| 备份 | 删除后审计保留、旧DB/JSON/ZIP、缺私人快照、重启恢复 | 不将私人原文字节加入普通ZIP |
| 设备 | iPhone13/Keychain/真实HTTP/Files/iCloud/签名/原版图标限制 | 各自DEVICE_BLOCKED，不阻止其他代码完成 |

## 4. 测试与安全的特别风险

`.github/scripts/verify_product_contract.py`目前断言旧题干`questionTextView.isScrollEnabled = true`等实现细节。施工必须将相关断言更新为三行/全文可达/阅读不评分的行为测试，同时保留精确85ID/12ACCEPT/6OPEN、安全写入/来源/回执检查。本次定稿不修改脚本，也不把旧脚本通过当新规格通过。
扩展读取文件类型不能扩大写入器权限，尤其`.excalidraw.md`虽以.md结尾也不能自动被普通笔记编辑流覆写。HTML/富文本不是源字节权威；渲染/材料解析升级不得失效旧来源key并擅自重绑。未知插件降级不能用于逃避明确支持格式。
删除会话不是撤销已执行知识修订；审计保留不等于保留全部聊天却谎称删除。待执行/已执行/中断未核实分别处理，异步保存不得复活记录。
私人Markdown批准快照仅保护目录；缺失就安全失败。原始数据“UI看不到”不等于已删除，不许卸载/清库/覆盖恢复来排查。

## 5. 执行/交付门禁

只修改指定分支，不动main/私库/原版AppIcon，不新分支、不破坏Git、不用Remote Desktop Commander，不付费模型。`ImVaultGuardedWrite.productionWriteEnabled = false`保持。所有测试使用合成无隐私fixture；任何真实授权与费用另核。
G1实际UI与历史功能，G2复杂格式和选材，G3双向闭环，G4同SHA完整测试/IPA/证据。每批先查远端保护其他提交，合并同类修复再跑CI，失败读取具体日志。新功能未实现、未执行、测试失败和设备外部阻塞分开标；不以更新文档代替开发。
本轮文档验收仅检查冲突替代、85稳定ID、ACCEPT/OPEN保留、子项映射、范围/许可/数据安全及八份稿件一致；没有新原生测试、UI实测或新IPA。

## 2026-10-21 · 施工后的真实缺口复核

**已推进（非最终验收）：** Excalidraw `compressed-json` LZ-String Base64 有界解码、基础本地绘图及选材/Chat 来源重校验、受限 PNG/JPEG 内嵌预览；双目标 `applying` 状态增加只读核验/确认阻断；新增可执行四 Tab XCUITest Target。代码证据 `b527764` → `b7a3e76`。

**仍为内部实现缺口：** Excalidraw 全格式真实渲染、Markdown 封装附件、区域/框架全部边界；Mermaid/Markmap 离线图形及分支选材；复合文档跨格式选择一致性；18步连续真实 UI E2E；F01～F13 全量故障注入和恢复；ACCEPT-01～12 新版证据、设备授权以及最终同SHA QA IPA。全部仍按原优先级施工，不转 DEFERRED 或 DEVICE_BLOCKED 以掩盖内部缺口。

## 2026-10-21 · B 方案与闪卡交互增量缺口

从 HEAD `a6051b46c78910cdb87ca8d16f8ccbd5b4467967` 的现有 Swift/Xcode 工程核验：`ImpressV3ReviewViewController` 卡内编辑/讨论默认建立，尚缺揭示后显隐门禁；`ImpressV3CardComposerViewController` 右上仍是文字保存；`ImpressCalibrationViewController` 有原生周/月/年图且 App entitlement 具有 App Group，但目前没有 WidgetKit Extension target。因此四子项 `CARD-08.a/UI-01.a/NAV-05.w/SAFE-08.w` 的源码与专项测试全属待施工，不是 DEVICE_BLOCKED。旧 QuickEdit 揭示前可见的断言必须替代，但来源/FSRS 安全测试不删。产品稿 §2.2/2.3、执行矩阵新增子项、SMOKE W01～W15 构成同一需求契约；CAL-01～15 原新算法仍 DEFERRED；85 主 ID/12 ACCEPT/6 OPEN/18 步 E2E/F01～F13 不更名、不减少。

## 2026-10-21 · e6b77b2 实现差距复核

最新已成功运行的证据：`e6b77b2` / Actions `39586231838`。WidgetKit Extension target、三 WidgetKind × Small/Medium 六布局源码、主应用的最小只读 App Group 数据投影、时间区间/日期状态 Core 测试、包含真实 `.appex` 的 unsigned ARM64 IPA 均**已经实现并构建验证**；此前“Widget Target 缺失”仅是定稿前历史缺口，不能再作为当前开发结论。原 UI 右上显隐、系统 checkmark 保存已通过原生 XCTest。复合文档 Excalidraw / Markmap / Canvas 曾失败的 XCUITest 此次全部通过；不能再写成当前 FAIL。

后续门禁：真机签名/桌面 Widget 六布局、App Group 与侧载权限、深链真实点击（已新增专项测试待下一轮）、完整版18步 E2E 与全部 F01～F13 真实异常注入/复测、数据恢复与全业务设备 QA。只有精确 SHA + Run/实测证据才能升级对应状态，不可把 Core PASS 扩张为真机 PASS。

## 2026-10-22 · 阅读视图代码审计与最小施工方案（G1）

精确基线：`5fd40c7b10be27a3a25c700fbe69630222130c93`，Actions #39734503921 SUCCESS（该 Run **不包括本次重构**）。

1. Frontmatter 直接进入 `renderBody` 的 Markdown 渲染串；现有 `ImpressMarkdownStructure` 仅跳过它的伪章节，没有 typed Properties 与阅读投影分离。需要真实类型解析、局部错误及源码访问，而非改 CSS。
2. 嵌套列表首先核查 Markdown 原始语法与 `MarkdownView` HTML 生成，再校准 `ImpressV3Appearance.markdownReaderCSS` 缩进、行高、任务状态；源码模式不能作为阅读成功。
3. `ImVaultSafetyProjection` 是保护外部图片与 WikiLink 的显示投影，不能用投影文本偏移当原始范围。`safeMarkdownProjection` 只解析内嵌图片且最多 6 项；未支持的 Canvas/Excalidraw 嵌入不应标为已实现。
4. Canvas 与 Excalidraw 已有原生、可缩放、可选材的只读实现；离线 Mermaid/Markmap host.js 已实际渲染图形。优先复用，补 Markdown 插槽/受限资源桥，不重新开发绘图算法。
5. `MarkdownView.load` 在每次展示时重配置底层 WKWebView；必须评估一次初始化与增量渲染的兼容性，避免显示预览后重复创建 web 内容进程。
6. 保留来源回读、版本验证、正式写门禁=false、原有 UI E2E。新的复杂 YAML、插件自定义语法与不支持格式一律诊断而非伪造。

**验收事实禁止越级**：Core 测试成功只证明解析；模拟器截图不等于用户截图视觉对齐；旧 Actions SUCCESS 不等于此次新 SHA SUCCESS；真正设备/Files Provider/App Group 验收必须独立标识。

## 2026-10-22 · 源码与验收区分：图形/数学渲染误判防护

已排查到旧 XCUITest 仅等待 `ready`，即使图形未出现在 DOM 也可能误判；`markdown-host.js` 中 `$$` 块公式分隔符曾被误写为 `$`。当前修复正由新源码 SHA 的 CI 验证：Bridge 回传实际 SVG/KaTeX 计数，UI 不再把空渲染器当成正确图形。既有图形选材/Chat 来源授权单独走原生 SHA 回读，不依赖此指标授权传输。普通笔记不主动加载 Mermaid/Markmap；只在检测到相应代码围栏时加载离线打包资源。

当前嵌入 Markdown 的边界是**同一已授权 Vault、只读一层、20KB 文本投影、确切唯一章节**。未知块 ID、外链、循环、嵌套插件及范围不明依赖都必须局部降级。安全降级不等于 Obsidian 所有插件能力已交付。

## 2026-10-22 · 六截图后 G2：真实代码分叉与架构候选（只记录，不实施）

基线为本次复核打开的 `feature/impress-duplex-loop-v1`；最终实际 SHA 需在下一次 CI/设备记录，不沿用历史 PASS。

1. **Markdown 并非完全无阅读引擎**：`ImVaultDocumentController.richView = ImpressMarkdownOfflineView()`；这个本地 `WKWebView` 由打包 `MarkdownReader/index.html` 初始化，`markdown-host.js` 通过 `markdown-it` 输出 HTML，并结合 KaTeX 与惰性加载 Mermaid/Markmap。旧文件仍 `import MarkdownView`，但当前 `renderBody` 调用的是新封装 `richView.load`。执行矩阵中的「MarkdownView.load」为早期源码快照说明，不得作为本 HEAD 的精确调用类型。**真实缺口**是 Markdown token/DOM/CSS + native Properties/标题页面的组合布局、嵌入与实际构建资源覆盖，没有经私有截图同设备视觉验收。

2. **截图文字层级错位有明确结构风险**：页面 native `documentTitleLabel` 与可折叠 `propertyPanel` 放在 `readerHeader`；Properties 用额外圆角 surface，正文又在下方 `richView` 与独立 inset 体系；`markdown-index.html`/Appearance CSS 可能叠加块 margin、列表 padding、嵌套 list item 的行高；不能把这种跨层 UI 差异仅归因于字体或一种 Markdown 解析器。

3. **Excalidraw 的格式分派已有初步代码，但截图只见数据**：`ImVaultDocumentFormat.detect` 优先判定 `.excalidraw.md`；`renderBody` 将 `.excalidrawJSON/.excalidrawMarkdown` 路由到 `ImpressExcalidrawScene.parse` 和 `ImpressExcalidrawNativeView`。实际旧 IPA、文档被当普通 MD 打开、解码失败、源码模式、缺少图形资产/元素类型、内嵌引用的回退分支均需用文件路径/运行日志/测试精准定位。当前失败样式不应被说明为正常的 Obsidian 画布。严禁把插件压缩正文替换成无来源授权的纯文本传给模型。

4. **卡片/目录/Chat 的源码反证**：`ImpressV3ReviewViewController.configureRatingGuide` 明确建立四个 chip，`setCurrentCardActionsRevealed` 恢复固定高度；`ImpressNoteListTableViewController.tableViewSetting` 明确创建 `UIRefreshControl`，多个刷新路径 `tableView.reloadData`；Chat composer 的 Material/STT/Send 按钮分别固定 44pt 宽，外框/内间距和 keyboardLayoutGuide 共同导致肉眼臃肿。都属于实际代码未按最新反馈改正，不能再以“UI 已完成”关闭问题。

5. **阅读架构比较（待用户同意选型）**：A）只换 `swift-markdown`/MarkdownUI 等原生渲染，适合普通 Markdown AST，却需额外自行实现 Obsidian Dialect、图形、源范围、Excalidraw；不建议单独替代全链。B）复用现有离线 `WKWebView + markdown-it`，统一渲染 DOM 与 CSS tokens、完善真实嵌入、原生来源索引和 Properties 布局；作为低风险基础方案。C）对 Excalidraw 高保真部分，在原生适配与官方 `@excalidraw/excalidraw` 离线只读 exportToSvg/轻量视图之间，基于覆盖率、离线包体、启动/内存、iPhone13 性能、元素命中选择、许可和来源映射完成技术试验后再决策。**禁止同时长期维护两套不一致的画布业务引擎**；共享事实身份/坐标/选材契约，渲染可替换。

6. **验收阻断**：未能取得当前安装包完整 SHA、真实 Excalidraw 示例和同设备屏幕记录前，无法归因到某一条代码。当前仅锁定用户**要实现什么**及候选方案，正式代码不动、旧 PASS 不挪用、新实机回归保持 NOT_RUN。保留独立 Vault 只读、安全型 HTML、不运行插件 JS/Dataview、禁止 CDN、无自动外网访问及 `ImVaultGuardedWrite.productionWriteEnabled = false`。

### G2 技术定位补录：为何源码有阅读器却仍出现截图中的巨大卡片、偏移与画布失真

- **叠层几何证据**：`ImVaultDocumentController` 在 header 单独放 `documentTitleLabel` 和 `propertyPanel`，正文再给 `richView` 配统一 `screenInset`；`ImpressV3Appearance.styleVaultDocument(richView)` 明确为整块正文设置 `surface` 和 `Radius.card`，而 `markdownReaderCSS` 又设置 `.markdown-body` 的 `padding: 24px 20px 44px`、标题 `margin-top: 1.45em`，`markdown-index.html` 另外维护嵌套列表/CSS。多个不同坐标系统与大内边距叠加，是截图「每篇笔记被大卡片框住、文字密度低、列表层次错位」的可查证原因之一；新验收应删除整页大卡片外观、采用统一 viewport 与 typography tokens，测量一次排版，而非盲目加 CSS 权重。

- **画布保真度确有技术上限**：现有 `ImpressExcalidrawNativeView` 将每个元素变成 `UIButton`，`CAShapeLayer` 只以简单 `UIBezierPath` 绘制矩形/椭圆/菱形/折线/箭头/手绘直连线；文本使用系统 body font，颜色处理主要针对 7 位十六进制值，复杂粗糙笔触、绑定文字、曲线/笔压、箭头端样式和插件式多层图形未必保真。因此“已经绘出形状”不能当成“达到 Excalidraw/Obsidian 级渲染”；优先做实际真实合成场景与官方 SVG 输出的画面对照，再决定采用高保真离线渲染器还是继续完善原生实现。

- **潜在格式误判（需真实文件验证）**：当前 `ImVaultDocumentFormat.detect(relativePath:)` 仅以 `.excalidraw.md` 后缀识别画布；若 Obsidian 插件生成的是普通 `.md` 文件却内含 `excalidraw-plugin: parsed` + 有效 Drawing code fence，则会被路径分类为普通 Markdown 并在阅读视图显示 `Excalidraw Data`。此为**代码可证的潜在失配路径**，尚不能断言就是用户截图文件：必须验证完整相对文件名/合法 drawing payload/安装 SHA。新增有限只读内容特征判别时，要同步阻止把 Excalidraw 封装文档误交给普通 Markdown 写入器；`tags: excalidraw` 单独出现不应自动视为有效画布。具体签名方案仍需用户确认技术路径后实施。

## 2026-10-22 · G3 实施前技术边界（基于实际现存数据流）

- **单滚动结构切割点**：`ImVaultDocumentController` 目前布局是 `readerHeader` 在上 + `readingView` / `richView` / `canvasHost` 相同内容矩形。将默认 `.markdown && !isSourceMode` 改为 WK 原生内文档 title/Properties/body 的一体化滚动，源码/Canvas/独立 Excalidraw 可继续拥有自己的内容 host 与导航；不要为了改 HTML 把全部 Canvas 自有手势迁入同一页。
- **已有 YAML 安全事实权威**：`ImpressFrontmatterReader.parse` 返回 `state/fields/body/bodyStartUTF8/diagnostic`，各 `field` 自带 `kind/values/rawValue/startUTF8/endUTF8`。Swift 做 typed parse 与失效诊断，再将白名单的只读属性展示模型送入 WK；不可另写一套 JS YAML parser 造成解释冲突。属性展开状态是纯 UI，而不是对真实 YAML 的修改。
- **真正的关键风险是选字定位**：`ImpressMarkdownOfflineView` 目前的 WK 桥仅有 `markdownState`（状态报告）和 WikiLink 点击，**没有通用 Web text selection→源字节区间**的可信桥。当前 `ImpressMarkdownStructure` 可提供章节 UTF8，尚不足以为任意 DOM 文本选区构造精确 UTF8；若 S1 改结构后宣称能从纯 HTML 精确选字，则必然引入来源安全漏洞。必须新增来自 source AST/token 的映射及只读范围 re-read gate，未实现前标明「精准选字功能未验收」，不得删除既有章节选材以求省事。
- **Excalidraw 类型误判与写入门禁同时修**：路径后缀分派不是完整 Obsidian 插件识别。增加只读展示分类时必须同步对“普通 md 路径却是画布源”的 generic Markdown draft 守卫；历史源身份与 backed-up Chat Key 不修改。仅当 Frontmatter + 可有界解压的 Drawing 数据并存才识别，不靠某个 `tags` 值猜。
- **离线现状足以复用**：`Scripts/DiagramReader/build.mjs` 已打包固定版本 markdown-it 14.1.0、KaTeX 0.16.22、Mermaid 11.12.2、Markmap 0.18.12；CSP `default-src 'none'`、`connect-src 'none'`、`img-src data:`、WebKit nonpersistent 已存在。G3 不应推翻已有离线资产边界，调整资源 bundle 须重产 manifest/hash/licenses 并同 SHA 构建。单独 Excalidraw SVG 方案只做固定 fixture A/B 和依赖/许可证审查，不擅自加入 CDN、React 编辑器或新的网络访问能力。

## 2026-10-22 · d9711284bfe2 最新源码与历史审计差异

旧 G2 说明属于较早的施工时点，不能作为当前源码事实：Review 已不再定义 configureRatingGuide/ratingGuide 四枚控件；笔记一级页已将 refreshControl 置 nil；ImVaultDocumentController 对普通 Markdown 阅读态已隐藏原生 readerHeader，将文件标题、类型化 Properties 和正文交由单个 WKWebView 呈现。这些属于 SOURCE_AUDITED，不是 U17/U20 或 RDR 的真机 PASS。

仍存在的可查缺口：Chat placeholder 与 UITextView 的垂直基线不同、输入区高度和附件布局/键盘边界需要实测；Markdown CSS 在 markdown-index.html 与统一 Appearance 内重叠、深层列表/任务 DOM 语义待验证；WK 桥仅上报图形状态与受控 WikiLink，不能可靠地把任意 DOM 选字映射为原始 UTF8，禁止猜测；Excalidraw 独立原生 UIButton/CAShapeLayer 缺复杂手绘/曲线/绑定文本的官方级视觉对照；部分真实 Markdown 嵌入图形的打开完整阅读/选材交互缺 E2E 证据；笔记索引多个 reloadData 路径尚需版本 diff。生产 Vault 写入门禁保持关闭，旧 CI 不冒充新验收。

## 2026-10-23 · 用户最新四项确认的源码根因（非施工完成声明）

1. **Chat 整体违背 ChatGPT 式对话形态**：当前 UITableView 的 ImpressChatMessageCell 在 configure 中强制 roleLabel="我"/"AI"、通用纵向 column + UITextView，并按角色设置整个 cell 背景色；不是仅按钮位置问题。应分离源消息/显示块/布局，优先 UICollectionView 自适应单元 + typed rich blocks + Diffable stable IDs + streaming scroll anchor，不以换颜色代替架构重构。UIKit 无需整体换 Web；MessageKit 等偏通用左右消息气泡，并不能直接保证 ChatGPT 的非对称 AI 文档式渲染。
2. **Chat 附件 B 缺真实传输**：当前 materialButton 唯一目标 reviewSessionMaterials()，没有 photo picker/document picker/camera；ImpressAIHTTPClient.converse 的 turns 目前只有 role+text，多 Provider 仍单次返回。仅接 UI picker 不等于「附件发送成功」；必须新增安全沙箱暂存、能力矩阵和分协议序列化，保留模型费用/来源审批边界，不能误发图像到纯文本路由。
3. **Excalidraw 图片中的框/箭头存在、文字低可读**：当前以 UIButton + text label 与 CAShapeLayer 分开绘图，默认颜色/源文本绑定、transform/points/坐标需逐合成场景验证；原生画出形状不等于官方高保真。正式修复以 source scene 与官方 SVG A/B 为准，避免直接把用户图形截图或笔记传公开仓库。
4. **校准日锁定缺持久化守卫**：CalibrationDayCheckIn.isComplete 是 computed 判定，setOutcome 允许直接更改；ImpressCalibrationLocalStore.save(checkIn) 可覆盖同日已完成记录；ImpressCalibrationViewController.tableView 固定3节、四项永远展示，并可通过额外行为按钮修改。必须在 Actor 保存层对已有完整当天 snapshot 添加拒改、UI 以保存成功的 CLOSED 投影动态隐藏四项录入节并禁用额外修正；只隐藏 section 将留下重入漏洞。

本节仅为源码事实与新的产品判定；截至此确认未提交对应修复代码，不把上一轮 CI 当作本轮 PASS。

## 2026-10-23 · Chat 渲染框架候选与风险（研究结论，不是开发交付）

当前 `ImpressChatMessageCell` 强制角色标签、普通 `UITextView` 与整行背景；`ImpressAIHTTPClient.converse` 以单次文本请求返回，是实际代码事实。选型不应直接等于换 `UITableView`：分别度量容器滚动/单元复用、Markdown 解析/布局、网络 SSE/取消/持久化。社区候选包括 MIT 的 `ekazaev/ChatLayout`（自适应单元＋稳定滚动，需关注 iOS 18 起 supplementary views 的维护变化）、`microsoft/SwiftStreamingMarkdown`（原生混合 Markdown/公式/代码/引用）、`gonzalezreal/textual`（新一代 SwiftUI 文本）、`joydle/rill`（脏尾增量 AST，社区成熟度仍需证明）、`exyte/Chat`（附件界面参考）；`oriveo/oriveo` 作为 AGPL-3.0-or-later 的多 Provider 混合 UIKit/SwiftUI 架构研究材料，禁止未经许可审查复制源码。参考 Gemini 的混排多模态、Claude 的成果分离阅读、DeepSeek 的模式切换时，不得冲淡 ChatGPT 作为 Impress 唯一主视觉标准或放入并不存在的产品能力。

**严谨性能契约的试验要求**：无界 token 对整篇 Markdown 重解析、对全部历史列表 reload、每条消息一个 WKWebView、网络事件直接触发多次 AutoLayout、以及滚动位置每帧强制跳到底部均是需禁止或证明等效性能的高风险路径。固定长段中文/emoji/数学/代码/表格/不闭合围栏/附件/长聊天与随机 token 切块；测试最终文本 AST 与一次性解析结果一致、错误和取消不会误作 completed，校验 stable messageID、Dynamic Type、键盘、复制选择、前后台、缓存释放。分别在 iPhone13 用 Instruments/OSSignpost 测量 FPS/hitches、主线程时长、峰值/回落内存、滚动偏移与 IPA 增量，不填报未量实测数值。Chat `TECH_DESIGN_OPEN`；Excalidraw 与 CAL 产品规则仍冻结。
