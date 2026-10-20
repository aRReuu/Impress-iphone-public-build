# Impress V1 · Obsidian 真机写回 QA 操作规范

> **实现性质：仅 Debug QA；生产写入开关仍为 `false`。** 这不影响原文阅读和独立草稿编辑，但 **Release 构建无法通过 Impress 修改正式 Obsidian 原始文件**。真机文件协调、正式 Vault 精确授权和云端状态验收完成前不可开放。
>
> 目标是让使用者在 iPhone 的真实 Files / iCloud File Provider 中验证受控 Markdown 写入、SHA 版本检查和恢复副本，**而非授权 AI 自动编辑其日常 Obsidian 原始 Vault**。
>
> 开发分支：`feature/impress-vault-device-write-qa`，从 `feature/impress-ai-api-questionpool-impl` 的最新成功 CI 版本分出。没有改动 main、校准器或 FSRS 评分逻辑。

## 1. 明确保护边界

- `ImVaultGuardedWrite.productionWriteEnabled = false` 仍然保持。
- 本 QA 分支仅在 `#if DEBUG` 编译条件下开放手工差异确认后的单文件写入，`Release` 下不允许。
- 必须通过 iOS `UIDocumentPicker` 明确选择并保存对应文件夹访问授权；其根目录**必须**准确命名为 `Impress-Write-Test-Vault`。
- `Impress-Write-Test-Vault-Old`、`MyObsidian`、`Vault` 等名称均被拒绝；重定向到其他根目录的路径不能绕过校验。
- **不直接支持操作日常工作 Vault**。先将少量、无隐私的笔记复制到独立测试文件夹，严禁把原始 Vault 直接改名用于测试。
- 每次仅写入明确选择的一份 Markdown；必须先存储完整编辑草稿、展示未截断的完整差异并得到用户再次确认。无隐式批量写入。
- 原文在 `NSFileCoordinator` 协调的写入期间重新校验 SHA-256，检测版本冲突则拒绝。
- 每次实际修改前将原始**字节级副本**保存在 App 私有 Application Support 的 Recovery 目录中，验证成功才尝试写入，写入后再次读取验证。
- `ImVaultGuardedWrite.commitFixture` 仍然只支持 App 的 `temporaryDirectory` 中的测试根目录，不因真机 QA 额外入口而放宽。
- QA 权限不会持久启用为全局写开关：用户每次进入差异页并点击确认才发起当前写操作，实际写操作始终再次验证当前授权 Vault 根目录。

## 2. 真实 iPhone 13 / Files / iCloud 验收步骤

1. 在 Files App 中建立**完全独立、可丢弃的文件夹** `Impress-Write-Test-Vault`，放入至少两篇自己构造的、不含私人数据的 Markdown 文件。可以先在“我的 iPhone”本地 Files 测试，再复制同名文件夹到 iCloud Drive 进行 File Provider 验证。**不要操作日常 Obsidian Vault。**
2. 使用此 QA 分支编译的 **Debug ARM64** 构建，通过用户自己的有效签名/侧载方式安装。GitHub Actions 输出是无签名测试产物，不能视为最终发行安装包；公开构建仍缺少权威原始 1024px AppIcon。
3. 打开 Impress → 闪卡顶栏「笔记」→ 连接 Obsidian Vault → 在 iOS 文件选择器中选择刚建立的 `Impress-Write-Test-Vault` 文件夹。
4. 打开一篇测试 Markdown。确认原文可阅读、来源和章节正确，然后点击「编辑独立草稿」。
5. 编辑一小段，保存草稿，进入「查看差异」。仅当来源版本无冲突、Diff 未截断，而且授权根目录**准确为指定 QA 文件夹**时，才会出现可点击的「测试副本写回」。
6. 阅读第二次警告，明确点击「确认测试副本写回」。成功结果应当来自写入后重新读取的字节比对，而不只是 UI 乐观状态。
7. 在 Files App 及 Obsidian（如果用其打开测试副本）检查具体内容；重新打开 Impress 读取测试文件，确认更改一致。**iCloud 文件本地成功不等于云端同步成功**，需在另外一个设备或 Web 文件列表核查云端同步（如有）。
8. 拒绝用例：重新授权日常原始 Vault（名称不同），编辑一份草稿、查看差异，确认测试写回按钮保持不可用；原文件未修改。
9. 冲突用例：先从测试 Vault 建草稿，再在 Files 或其他应用修改同一篇测试源文件，然后回到 Impress，必须报告版本冲突，不能覆盖外部修改。
10. 失败用例：关闭 Files 权限、断开 iCloud 下载或制造无权限目录；请求必须失败且保留草稿，不能在本地凭空重建原始文件。
11. 恢复用例：成功写入之后，保留 App 的 Recovery 原始副本，核对其内容与本次修改前一致。删除 App 会丢失 App 私有恢复副本，因此重要测试数据另行备份。

## 3. 尚未通过的门槛

- 以上真实 iPhone 13、不同 Files Provider、iCloud 同步端到端测试必须实际执行。GitHub Xcode Simulator 的通过不等于真实 iCloud 已 PASS。
- 此 Gate **只支持手工 Markdown 草稿的受控写回**；不能据此声称已实现「API 模型自动跨文档知识重构」。AI 自动修改仍然需要模型 edit plan、工具检索、语义依据校验、跨文件事务与审阅策略。
- 不能在私人 Vault 上进行尚未验证的覆盖性测试，更不能合并 QA 开关到正式发布路径。
- 一旦 QA Gate 完成，可以另行评估生产级“明确授权 + 默认审阅 + 可恢复写回”的设计，不再依赖 Debug 目录名。

## 2026-10-20 · 从 Chat 进入笔记草稿

- 关联卡片的 **已完成 AI 消息** 可通过长按菜单选择「在关联笔记草稿中整理」。
- 必须验证当前 Vault 授权且能成功重读同一个完整路径，不使用笔记标题猜测目标。
- 菜单仅打开现有的原文保护式草稿编辑器，不自动把整段聊天贴入笔记，也不发送文件或写入原件。
- 用户在草稿中亲自选择必要文字修改，先看 Diff；只有 Debug 独立 QA Vault 在逐项通过后才能触发可回读的测试文件写入。
- 生产 Vault 的任何首次真实写入需另行满足设备与具体目标授权 Gate，不把 Chat 结果或保存草稿误报为已更新原文。
