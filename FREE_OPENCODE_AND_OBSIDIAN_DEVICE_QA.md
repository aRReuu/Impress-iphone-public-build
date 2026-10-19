# Impress V1 · OpenCode 免费模型 + Obsidian 真机验收

> 适用：`feature/impress-vault-device-write-qa` 的 Debug QA iPhoneOS 构建，不适用于公开发布。此阶段只允许免费模型的网络推理，**不得向付费模型发请求**；正式 Obsidian 生产写回始终关闭。
>
> 当前 OpenCode Console 官方模型目录：`https://opencode.ai/inference/v1/models`；
> 免费 Chat Completions Endpoint：`https://opencode.ai/inference/openai/v1/chat/completions`。
> 本 QA 仅允许 OpenCode 官方价格表明确列为 Free、且公开目录可查询的四个型号：`mimo-v2.6-flash-free`、`longcat-2.5-preview-free`、`nemotron-3.5-lightning-free`、`space-bunny-free`。不接受自行输入未知 `-free` ID 来绕过白名单。

## A. 连通性与 API Key（无私人笔记）

1. 打开 `设置 → AI 服务 → + → OpenCode 免费模型（测试）`。该入口创建或更新现有免费 QA 连接，不会清除已经授权保存的 Keychain 密钥；默认模型为 `mimo-v2.6-flash-free`，可选其余三个 Free 型号。
2. 优先在此连接保持 **noAuthentication**（不需要 API Key），从模型列表点 `测试免费对话`，只会发送一个不含用户数据的 `ping` 请求。
3. 官方文档允许匿名免费聊天，但在 [GitHub Hosted Runner 测试 #39201745545](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39201745545) 中，新四个 Free 模型均在目录存在（GET 200），实际匿名 POST 全部 HTTP 403。这不代表有 Key 的 iPhone 请求一定失败，也不代表有 Key 就一定成功。
4. 如果手机上也提示 403，点击该免费连接的 `API Key`，将你在 OpenCode Console **重新生成的**密钥保存进 iOS Keychain。原匿名免费连接随明确录入自动切换为 `bearer`。重新点击 `测试免费对话`；请求中的模型 ID、接口和数量限制仍保持免费策略。
5. 推荐从模型操作菜单点击 `免费 API 全链路验收`。用户确认后，如果已保存 `oc_sk_` 服务账号 Key，会先用同一 Keychain 凭据调用官方 `GET https://opencode.ai/console/api/v2/config`（只检查 HTTP 状态，不读取或记录账号配置），再依次执行首次 Chat、第二轮带历史 Chat、JSON 解析、模拟章节综合出题 + 候选池证据校验。匿名模式跳过服务账号鉴权。四项推理全部真实 HTTP 成功，才会标记该模型 `jsonVerified` 并启用 Chat / 出题默认路由。该按钮**不会上传个人笔记或写入正式卡片**。如果任一环节失败，必须查看服务商、模型 ID、协议、HTTP 状态和失败原因；换另一个仍属 Free 的型号即可，不回退收费模型。
   - 在 `设置 → AI 服务 → 默认对话提示词` 可选用现有「提示词」库中的自定义模板，默认仍为「第一性原理 + 奥卡姆剃刀」。提示词模板可以从入口跳转原有提示词编辑页面；只有显式点击发送才会与用户输入一起传给服务商。
6. **`-free` 后缀不保证永久免费。** OpenCode 的 Free 定价属于当前状态，且一些是限时活动。测试前需在 Console 再次确认模型免费定价及当前账户计费设置。如要求完全零账单风险，可以优先尝试匿名请求；账号 Key 需由用户自行在设备 Keychain 中录入、撤销和更换，不在仓库或 CI 保存。

## B. Obsidian 只读、出题与候选池

1. 在 iPhone 的「文件」App 中新建 `Impress-Write-Test-Vault`（**必须是独立的可丢弃测试副本**）。
2. 从本仓库下载 [Impress QA 知识样本](Tests/Fixtures/Obsidian/Impress_QA_Knowledge.md)，复制进该文件夹。不要授权正在使用的私人 Vault，也不要将日常 Vault 改名成测试目录。
3. 打开 `闪卡 → 笔记 → 连接 Obsidian Vault`，在系统文件选择器中选取测试文件夹，确认可以读取样本且未修改原件。
4. 进入样本详情，选择「生成综合问题」、勾选目标章节并将题数设为 5；明确确认 **仅上传该测试资料** 到当前免费模型。出题结果只进入候选池，不会自动入库。
5. 候选池核对题干、参考答案及证据，编辑或删除无效项。候选池会以原子快照保存到现有 Vault 私有数据目录；关闭应用后，重新打开相同笔记的「生成综合问题」入口可选择恢复。若原笔记 SHA-256 已变化，禁止直接恢复导入，只能重新生成。主动确认后才写入 V3 WCDB 并启动 FSRS；取消或 API 失败不得改变数据库。
6. 即使免费 Chat 测试成功，仍需另行确认 JSON 探针与出题 Schema。有引用 ID 并不自动证明生成答案的语义正确。

## C. Obsidian 受控写回与冲突防护

1. 在 `Impress-Write-Test-Vault` 中打开测试 Markdown，点「编辑独立草稿」，修改少量字句。
2. 先保存独立草稿，查看完整差异；确认后执行 `测试副本写回`。
3. 在「文件」App 中重新打开原件，确认字节内容已实际变化；把原始内容与 App 私有 Recovery 副本对照。使用 iCloud Drive 时，还要在第二处核实云端同步，**本机写成功 ≠ 云端同步成功**。
4. 再建草稿后，从 Obsidian 或文件 App 修改同一源文档，回到 Impress 重试写回；必须报版本冲突并保留草稿，不能覆盖外部修改。
5. 在正常的生产 Vault 根目录，写回按钮必须始终不可用。
6. `Release` 配置下所有这种设备 QA 源文件写回应当继续关闭。

## D. 可信结果边界

- GitHub Swift/XCTest/ARM64 绿灯只能证明相应自动化通过，**不能证明真实 iPhone Keychain、OpenCode 账号、iCloud File Provider 已 PASS**。新的模拟网络测试验证普通文本、多轮回复与 HTTP 401/403/404/429，但它们不能代替真机实际调用。
- 免费模型连接测试应显示实际 Provider、模型 ID、Chat Completions 协议及成功 HTTP 状态；失败也显示模型/协议和 401、403 或 429 等错误类别。不会自动选择付费模型。
- 对外部服务 HTTP 401/403、格式不支持、权限限制，要报告实际错误，不能自动尝试收费模型；不要在公开 CI 打印 Key 或请求体。
- 原生 Chat 暂为临时会话，不自动写入 Obsidian 或理解历史。**知识重构与正式 Vault 写回仍是后续独立 Gate。**
- 公开仓库维持 `main` + 一个开发分支；本任务不操作私有仓库。
- 你此前在聊天明文提供的 OpenCode Key 应当**撤销并轮换**；请将新 Key 仅录入 iPhone Keychain。
