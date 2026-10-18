# Impress V1 · OpenCode 免费模型 + Obsidian 真机验收

> 适用：`feature/impress-vault-device-write-qa` 的 Debug QA iPhoneOS 构建，不适用于公开发布。此阶段只允许免费模型的网络推理，**不得向付费模型发请求**；正式 Obsidian 生产写回始终关闭。
>
> 当前 OpenCode Console 官方模型目录：`https://opencode.ai/inference/v1/models`；
> 免费 Chat Completions Endpoint：`https://opencode.ai/inference/openai/v1/chat/completions`。
> 本 QA 仅允许 `glm-5.3-flash-free` 和 `deepseek-v4.1-flash-free`，禁止通过输入其他模型 ID 或修改 Gateway 地址绕过。

## A. 连通性与 API Key（无私人笔记）

1. 打开 `设置 → AI 服务 → + → OpenCode 免费模型（测试）`。该连接自动创建两个免费模型，出题与原生对话均默认使用 `glm-5.3-flash-free`。
2. 优先在此连接保持 **noAuthentication**（不需要 API Key），从模型列表点 `测试免费对话`，只会发送一个不含用户数据的 `ping` 请求。
3. 官方文档称免费聊天模型可以匿名请求，但 GitHub Hosted Runner 对这两个免费模型的匿名 POST 实测均返回 **HTTP 403**；公开模型列表请求为 **HTTP 200**。这不证明 Key 错误，也不证明 iPhone 所在网络一定被拒绝。
4. 如果手机上也提示 403，点击该免费连接的 `API Key`，将你在 OpenCode Console **重新生成的**密钥保存进 iOS Keychain。原匿名免费连接随明确录入自动切换为 `bearer`。重新点击 `测试免费对话`；请求中的模型 ID、接口和数量限制仍保持免费策略。
5. 免费对话通后，再点击 `测试 JSON 输出`，成功时才允许进入「指定笔记生成综合问题」；若模型无法严格遵循 JSON 格式，尝试另一免费模型。切勿回退付费型号。
6. 注意：**只因名称带 free 不能保证永久免费。** 模型目录与定价由 OpenCode 修改。本 QA 代码只允许官方文档确认为免费的两个型号；实际用量是否最终计费取决于服务商。如要求完全不承担账号费用风险，请保持无认证方式；Keychain 带 Key 测试需要用户在 Console 核实免费定价。

## B. Obsidian 只读、出题与候选池

1. 在 iPhone 的「文件」App 中新建 `Impress-Write-Test-Vault`（**必须是独立的可丢弃测试副本**）。
2. 从本仓库下载 [Impress QA 知识样本](Tests/Fixtures/Obsidian/Impress_QA_Knowledge.md)，复制进该文件夹。不要授权正在使用的私人 Vault，也不要将日常 Vault 改名成测试目录。
3. 打开 `闪卡 → 笔记 → 连接 Obsidian Vault`，在系统文件选择器中选取测试文件夹，确认可以读取样本且未修改原件。
4. 进入样本详情，选择「生成综合问题」、勾选目标章节并将题数设为 5；明确确认 **仅上传该测试资料** 到当前免费模型。出题结果只进入候选池，不会自动入库。
5. 候选池核对题干、参考答案及证据，编辑或删除无效项。主动确认后才写入 V3 WCDB 并启动 FSRS；取消或 API 失败不得改变数据库。
6. 即使免费 Chat 测试成功，仍需另行确认 JSON 探针与出题 Schema。有引用 ID 并不自动证明生成答案的语义正确。

## C. Obsidian 受控写回与冲突防护

1. 在 `Impress-Write-Test-Vault` 中打开测试 Markdown，点「编辑独立草稿」，修改少量字句。
2. 先保存独立草稿，查看完整差异；确认后执行 `测试副本写回`。
3. 在「文件」App 中重新打开原件，确认字节内容已实际变化；把原始内容与 App 私有 Recovery 副本对照。使用 iCloud Drive 时，还要在第二处核实云端同步，**本机写成功 ≠ 云端同步成功**。
4. 再建草稿后，从 Obsidian 或文件 App 修改同一源文档，回到 Impress 重试写回；必须报版本冲突并保留草稿，不能覆盖外部修改。
5. 在正常的生产 Vault 根目录，写回按钮必须始终不可用。
6. `Release` 配置下所有这种设备 QA 源文件写回应当继续关闭。

## D. 可信结果边界

- GitHub Swift/XCTest/ARM64 绿灯只能证明相应自动化通过，**不能证明真实 iPhone Keychain、OpenCode 账号、iCloud File Provider 已 PASS**。
- 对外部服务 HTTP 401/403、格式不支持、权限限制，要报告实际错误，不能自动尝试收费模型；不要在公开 CI 打印 Key 或请求体。
- 原生 Chat 暂为临时会话，不自动写入 Obsidian 或理解历史。**知识重构与正式 Vault 写回仍是后续独立 Gate。**
- 公开仓库维持 `main` + 一个开发分支；本任务不操作私有仓库。
- 你此前在聊天明文提供的 OpenCode Key 应当**撤销并轮换**；请将新 Key 仅录入 iPhone Keychain。
