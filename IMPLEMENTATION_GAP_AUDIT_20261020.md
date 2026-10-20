# Impress · 实施差距及防回归门槛（2026-10-20）

基准：`3e98db7cb0eb10ae6a0734a655fb3337d18d8fc2`（历史审计；后续修复并非已完成验收）。最新逐项表见 [REQUIREMENT_EXECUTION_MATRIX_20261020.md](REQUIREMENT_EXECUTION_MATRIX_20261020.md)；`897895c` 补选择题解析，`c38efbe` 补首页前置编辑与来源按钮。旧表 CARD-01/11、CHAT-03/04 的 FAIL 结论已存在后来源码变化，禁止不核实即重报。此页仅记录审计结论，**不是完工清单**。权威需求见 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。

| 需求范围 | 当前代码/自动化证据（最后完整成功 Run 39435321232 · dabbc9d） | 完整产品验收结论 | 下一门禁 |
| --- | --- | --- | --- |
| CARD-01～03 | 长题/答案 Markdown 独立滚动、H1/H2 等原生测试已通过；158/158 iOS XCTest 的前一基线。 | **自动化 PASS，真机 BLOCKED** | iPhone 13 Dynamic Type、长列表/表格阅读、选文与四向手势无冲突 |
| CARD-11 | 编辑器内保留内容历史，原生 `testContentHistoryIsEditorOnly`。 | **自动化 PASS，设备 BLOCKED** | iPhone13 实际入口/返回路径 |
| CARD-07～10 | 快速现场编辑、卡片 CAS、FSRS revision 隔离与揭示失效验证已有原生测试。 | **自动化 PASS，设备 BLOCKED** | 真机原队列/旧答案屏蔽验证 |
| CHAT-01～04 | 同源多会话、新建/历史切换、草稿、Markdown 消息及失败保存 XCTest 已通过。 | **自动化 PASS，设备 BLOCKED** | 真实 Keychain / HTTP / 中断恢复及多语言 UX |
| CHAT-05～08 | 模型/提示词与材料范围选择已有源码，发送前逐摘录和失败后跨 Provider 二次批准补强已准备，尚需新 CI。 | **部分自动化；新增安全门禁待 CI** | 同 SHA Xcode/XCTest、设备权限/真实请求 |
| CHAT-09～10 / LOOP-10～13 | 已有双目标预览、逐对象 CAS/回执、幂等、保护快照及独立撤销；同笔记重复修订的三项原生回归通过。 | **自动化核心 PASS，完整设备/异常验收 BLOCKED** | 强杀恢复、真实 File Provider、备份兼容边界 |
| LOOP-03 / 07～09 | 来源身份 v1/v2/v3、单节唯一 SHA、无关节低扰动、原卡来源核查；反向直接修订入口已提交，后续 SHA 测试待结果。 | **部分自动化；反向编辑新批次待 CI** | 文件移动/重复/权限撤销、iPhone 13 实际导航 |
| AI-01～07 | 默认四服务商+自定义、保留 GLM、自定义 Keychain、模型 ID/服务商搜索已有源码及原生测试。 | **自动化部分 PASS，真实服务 BLOCKED** | 不收费授权下的真实模型测试与多 Provider 交互 |
| SAFE-02～07 | `productionWriteEnabled = false`，QA fixture 的 SHA、备份、协调写、回读与逆向撤销已通过。 | **测试副本自动化 PASS，正式写回禁止** | 真实 Files/Provider、iCloud 同步、非加密 ZIP 不含私人原笔记 |
| ACCEPT-01～12 | 具有对应分层 XCTest 和完整 fixture 往返，但未运行完整实际手机 UX 及在线模型。 | **不得标记全部 PASS** | 每项 exact SHA 自动化/端到端/真机独立回执 |

**旧审计说明：** 本表原先记录在 `3e98db7...` 对 CARD/CHAT 的 FAIL，为当时真实缺口；不能忽视后续实际修复。最近完整验证层是 [Run 39435321232](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39435321232)，其后的提交必须以其各自 CI 结论另行认证。

### 为什么 128/128 XCTest 仍然导致产品 FAIL

1. 来源契约错位：历史 `KNOWLEDGE_LIFECYCLE_V1.md` 曾要求首页周图/历史按钮；最新需求将其替代，仓库未同步。
2. 断层：多会话 DAO 测试和最新会话恢复测试存在，但用户切换历史、新建对话 UI 没有测试，也没有完整实现。
3. 漏测：旧测试主要针对 WCDB/FSRS/SDK/IPA，缺少长文 Markdown 排版、触底可读性及手势冲突的系统验收。
4. 错误完成判定：`CI PASS` 只能表示该测试矩阵通过，不能证明设计验收或真实设备私有数据可恢复。
5. 交付文档滞后：README/SMOKE 与 latest commit 中的交互不一致；本文件建立可核对入口，不抹平历史。

### 个人数据安全

设备数据库：`Documents/ImpressV3/ReviewV3.sqlite`，Chat 表 `impress_v3_chat_session`（随完整 SQLite 备份，未经设备验证不得声称保全）。默认 Chat 根据 `sourceIdentity` 查询，只恢复 `sessions.first`，旧会话通常可能仍存而不可见。只读检查应先比对 Bundle ID、设备安装覆盖方式、容器路径、最近备份、旧 ID/迁移，再考虑任何更改。严禁 reset/uninstall/clean/覆盖式恢复。

### 自动化验收必须新增

- `testLongQuestionAndAnswerReadableWithMarkdownWithoutRating`：极端长 H1/H2、代码/表格、可完整滚动且滚动不会评分。
- `testCardHistoryOnlyInEditor`：复习底栏不存在历史入口，编辑器存在访问链接。
- `testNativeChatListsAllSessionsAndStartsSeparateConversation`：两个历史记录都可选；新建后原会话未变。
- `testSessionDraftRestoreAfterReopen`：退出重开保存草稿、消息与来源版本。
- `testApprovedFixtureProposalWriteReadbackAndPartialRecovery`：独立可丢弃 Vault；禁止正式 Vault。
- 重复保存、并发 CAS、失效权限、iCloud 未完成、退回原卡、深浅色/三语言以及 iPhone13 触底阅读。

## 2026-10-20 · 原闭环提交之后的可复核缺口与新修复

源代码复核发现：双目标原卡更新和“来源不影响”确认曾同时要求 **FSRS 调度 revision 等于打开页面时的旧值**，即用户正常评分也会让无内容冲突的已批准提案失败。修复使用写入瞬间的 FSRS revision CAS，同时继续要求原卡 contentRevision、原卡身份及来源身份精确一致；并新增真正评分后再批准编辑的临时数据库一体化 XCTest 场景。此外，“放弃剩余修改”曾可取消 `undoing` 目标，导致重启后把未完成撤销误判完成；修复状态机以及 UI 取消逻辑，Portable 验证旧坏快照仍维持待人工恢复。

**仍未完整验收：** ACCEPT-01～12 的完整原生交互、iPhone13 操作、真实 File Provider/iCloud/Keychain 与真实用户授权；正式写入始终 `false`。源代码实现和新增测试未经过最新 SHA CI 前，不得将上述修复标记 PASS。仍需按新 SMOKE 附表逐项判定。

## 2026-10-20 · P0：同一原笔记连续批准导致旧收据原字节失联

原 Chat 修改提案只存目标摘要，笔记原字节仍依赖每篇笔记唯一的活动草稿。二次修改覆盖旧草稿会使以前的 Diff/撤销不可恢复。修复为 Application Support 私有不可变 Approval 快照：依完整 Vault ID、相对路径、base/proposed SHA 查询，任何丢失/污染都拒绝写入。已应用草稿允许用户明确新建基于当前源文的下一版本，但必须再次读取真实来源、优先归档旧快照；外部冲突不覆盖原草稿。三项新增原生 XCTest 须以最终 HEAD CI 证明，设备与生产 Vault 仍是独立 Gate。

## 2026-10-20 · 修补反向流程入口缺口

原来源核查页只提供“确认不影响原卡”，缺少用户在该核查上下文直接修订原 cardID 的操作。现补共用原卡编辑器入口，在存储前回读源 Markdown 与来源 SHA，并按内容 CAS 更新用户明确修改的原卡、保留 FSRS。若来源变化或不同 Vault 则拒绝覆盖，不再强迫到卡片集通过标题搜索。完整手机实测与数据授权另行验收。

## 2026-10-20 · 新排查 P0：Chat 发送材料与供应商重复授权

此前 Chat 的 HTTP 门禁只比对整份源 SHA，而不复验已保存的单项摘录是否仍与真实笔记精确对应；还有一种可能：首次请求失败后 `activeProviderID` 未记录，但用户切换不同提供商，旧代码仅在出现 `completed` 消息时弹确认。为避免原文转发风险，现新增逐摘录字节/身份/版本验证及 40KB 精确边界；即使上次请求失败/取消，只要曾向某 Provider 发送过用户消息，改选服务商也必须重新确认。同时补反向原卡无改动误更新源摘要的问题；保留未发送草稿和模型选择。所有新门禁需新 CI 和设备独立验收。
