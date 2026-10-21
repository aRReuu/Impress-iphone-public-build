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
