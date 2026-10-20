# Impress · 实施差距及防回归门槛（2026-10-20）

基准：`3e98db7cb0eb10ae6a0734a655fb3337d18d8fc2`。此页仅记录审计结论，**不是完工清单**。权威需求见 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。

| 需求 | 审计状态 | 可复核证据 | 最小通过条件 |
|---|---|---|---|
| CARD-01～03 | FAIL | `ImMemoryCardView.swift` questionTextView.isScrollEnabled=false，raw text；答案 Markdown | 长题/答案在首页滚动到末尾，H1/H2/表格不溢出，手势隔离 XCTest 与 iPhone13 |
| CARD-11 | FAIL | `ImpressV3ReviewViewController` contentHistoryAction 仍占底栏；Composer 无历史入口 | 复习底栏不显示历史，编辑器有可到达的内容历史 |
| CARD-07～09 | PARTIAL | 现场编辑、CAS、无改动保护已有基础 | 保持相同 cardID/复习位置/FSRS，长文压力场景仍正确 |
| CHAT-01～04 | FAIL/PARTIAL | `ImpressAINativeChatViewController` UITableView subtitle cell；无新建/历史 UI | 同源可新建/选择/继续多个会话，Markdown 消息可选/复制，停止/失败保留输入 |
| CHAT-05～08 | PARTIAL | 只读全局提示词/模型覆盖、来源仅当前 cardID | Chat 内可见提示词/当前材料与范围，显式确认才发送，清空/变化安全 |
| CHAT-09～10 | NOT DELIVERED | 数据模型有 pendingProposal，但没有完整 Chat→统一 Diff→执行和恢复 | 测试源、原卡按确认范围修改，重开不覆盖历史/重复执行 |
| LOOP-03 | PARTIAL | Vault＋路径 + SHA、笔记关联卡片已接通 | 稳定片段身份/移动改名/撤权不串联 |
| LOOP-07～13 | NOT DELIVERED | 文件级变更提示，不是片段影响/受控执行 | 不相关段落不干扰；有冲突/部分成功正确回执 |
| AI-01～07 | PARTIAL | 默认五入口已缩减；模型搜索已有基础 | 所有入口行为/UI 核查，旧 GLM/Keychain 不回归 |
| CAL-01～15 / OPEN-01/06 | DEFERRED | 旧打分方案仍在；最新定版只是保留原则 | 绝不宣称已实现四固定行为方案，不为本轮主线阻塞 |
| ACCEPT-01～12 | BLOCKED | 旧 `SMOKE_TEST_MATRIX.md` A01～A20 为历史门槛 | 一篇独立测试笔记与一张原卡完整往返，有 exact SHA 证据 |

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
