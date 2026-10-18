# Impress V1 · 多 API 服务商与自定义连接验收规范

> 状态：已实现配置与路由代码；实机及真实付费账号调用尚未验证。此文档不宣称已完成生产发布或 Obsidian 写回。
>
> 分支：`feature/impress-ai-api-questionpool-impl`。**校准器、FSRS-6 核心调度、外部 Obsidian 写回门禁均不得改变。**
>
> **数据安全**：不得在公共仓库、CI、报告或截图中保存 API Key；私人笔记仅在用户主动选定章节且确认后发送。第三方 API 按其服务条款处理提交内容。针对长期公开分发，官方建议由受控后端代理管理生产 API 密钥；个人 BYOK iOS Keychain 模式无法保证密钥抵御已控制设备的攻击。

## 1. 配置设计

`设置 > AI 服务 > +` 可选择预设或 **自定义 API**，连接数量不设只有四个服务商的限制。每个连接独立：
- 用户自定义连接名称、Provider 类型、HTTPS Base URL；
- Keychain API 密钥引用，支持同服务商多 Key；实际密钥**不序列化**入配置 JSON；
- 认证方式：`bearer`、`rawAuthorization`、`apiKeyHeader`、`googleAPIKeyHeader`、`customHeader`、`none`；
- 自定义头名（仅安全 Header 名，可配置例如 `X-Custom-Token`）；不能覆盖 Host、Cookie、Content-Type 等受保护头；
- 相对路径：`models`、`chat/completions`、`responses`、`messages`，可逐项配置，不接受任意完整 URL、`..` 路径、Query 或 URL 编码注入；
- 一连接可添加多个模型，自动枚举只是便利，**不支持枚举时可手工输入模型 ID**；
- **每个模型可独立选择 API 协议**（适配混合网关）与 JSON 处理模式（原生/仅提示词约束）；更改协议或目标连接后必须重新进行无私密内容的 JSON 实测；
- 问题生成、知识整理、原生 Chat 各有业务模型路由。知识整理与原生 Chat 目前仍为后续 Gate，**不可将有路由配置误称为已启用**。

## 2. 预设示例（只用于填写方便，均可手动改动）

| 连接预设 | Base URL（不含操作后缀） | 默认协议 | 默认认证 |
| --- | --- | --- | --- |
| OpenAI GPT | `https://api.openai.com/v1` | `responses` | Bearer |
| DeepSeek | `https://api.deepseek.com` | `chatCompletions` | Bearer |
| Claude / Anthropic | `https://api.anthropic.com/v1` | `anthropicMessages` | x-api-key |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta` | `geminiGenerateContent` | x-goog-api-key |
| 智谱 GLM（国内） | `https://open.bigmodel.cn/api/paas/v4` | `chatCompletions` | Bearer |
| GLM / Z.AI（国际） | `https://api.z.ai/api/paas/v4` | `chatCompletions` | Bearer |
| Command Code | `https://api.commandcode.ai/provider/v1` | `chatCompletions` | Bearer |
| OpenCode Zen | `https://opencode.ai/zen/v1` | `chatCompletions` | Bearer |
| OpenCode Go | `https://opencode.ai/zen/go/v1` | `chatCompletions` | Bearer |
| **自定义 API** | 用户自己的 HTTPS 根路径 | 任选支持的协议 | 任选支持的方式 |

注：OpenCode 是客户端/平台生态，不等同于一种固定模型；其 Zen、Go 是独立 API 产品。Command Code 也同时提供 CLI 与 Provider API。智谱清言 Web 产品与 GLM 云端 API 不必共享同一凭证。**预设不是登录网页账号的替代物；请使用对应服务的 API 访问凭证与有效额度。**

Command Code 的 Provider API 提供 OpenAI 格式的 `chat/completions` / `responses` 和 Anthropic 格式的 `messages`：不同模型可能必须选不同协议。本实现允许在**一个 Command Code 连接内**为每个模型指定独立协议；协议格式不决定认证方式，Command Code 的 Messages 也使用 Bearer。

OpenCode Zen / Go 亦有混合协议目录；须按该模型支持的 endpoint 选择。无可用模型目录时保留手工 ID 输入。任意第三方 OpenAI-compatible 网关也无需新增 Swift 枚举或重新发布 App，只需自定义连接名称、Base URL、认证、相对路径与模型 ID。

官方文档参考：
- Command Code Provider API: `https://commandcode.ai/docs/provider`
- OpenCode Providers: `https://docs.opencode.ai/docs/providers/`
- OpenCode Go: `https://docs.opencode.ai/docs/go/`
- GLM Z.AI: `https://docs.z.ai/`

## 3. 出题任务与安全规则

`笔记详情 → 生成问题 → 默认5道综合题 → 选择章节 → 确认向当前 Provider 发送 → API → JSON/来源验证 → 候选池 → 编辑/删除/选择 → 明确确认 → WCDB V3 原子批量入库及 FSRS 初始化`。

- 模型返回不可信文本：必须严格 JSON 解码并做二次本地验证；枚举模型成功、JSON 探针 PASS **不等于答案真实可靠**。
- 对选定笔记 SHA 变化的情况拒绝候选入库；用户取消时不得新增卡片或写入 Obsidian。
- 不自动跨 Provider 切换；更换路由必须得到用户的明确配置授权。
- API 连接/模型能力测试不含真实私人笔记；手动触发出题时才可发送指定片段。
- 生产 Vault 写回门禁：`ImVaultGuardedWrite.productionWriteEnabled = false`，本阶段绝不改动。
- 账号、配额、协议错误只能反馈可读错误，禁止将响应体（可能含私密内容）记录到日志。

## 4. 测试与退出门槛

1. Core 测试：多 Provider/多模型/多 Key、混合协议、认证方式、自定义头名安全、Endpoint 相对路径拦截、兼容旧版配置 JSON。
2. iOS 原生：旧导航与新增“AI 服务/问题生成/快速记录”契约同时验收；不删除旧 FSRS、备份、Obsidian、校准用例。
3. 真机或授权测试账号：至少验证一个官方 Provider 与一个自定义第三方网关，独立确认 Keychain 读取、JSON 兼容、实际选中文档上传边界和 V3 原子入库。
4. 仅在 exact HEAD 的 CI 全绿后讨论合并；**模拟器通过不意味着 iPhone 13 端到端通过**。
5. 当前候选池仅处于页面内存，跨冷启动持久化和备份属于独立的待完成 Gate；不可谎称已经交付。

## 5. 非目标

本轮不实现原生多轮 Chat、不实现自动 Markdown 知识重构/写入、不修改校准器、不变更 FSRS 算法、不处理私人 Vault、不将开源工作转入私有仓库、不合并 main。
