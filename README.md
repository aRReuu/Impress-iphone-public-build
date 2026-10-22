# Impress — Public iPhone Development Branch

> **V1.1 开工前定稿，非功能交付。** 唯一产品权威：[PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。本轮只更新现有稿件，新界面/复杂格式尚未据此实施或验收。

唯一工作仓库为`aRReuu/Impress-iphone-public-build`，唯一开发分支`feature/impress-duplex-loop-v1`；不改main/私库，不创建分支，不同步私库、不替换原版AppIcon。`SOURCE_MANIFEST.json`中的历史上游只供追溯，不是修改私库的授权。

## 当前定稿产品

一级Tab目标为**闪卡／笔记／校准器／设置**；默认闪卡，Chat次级。恢复已有校准器入口/数据不意味着实施新公式、迁移或提醒；不恢复首页周图。
笔记 Tab 一级页采用 Obsidian 式层级可折叠原生目录：只显示文件夹名称／文件标题、缩进与必要 chevron，**无装饰 Icon、相对路径或文摘副标题**；搜索覆盖折叠子孙，清空恢复展开状态。真实来源路径、Vault 授权、分页、刷新、身份和回读仍保留在数据层。归现有 UI-03/NAV-03/SAFE-03（子项 UI-03.a），不新建笔记存储。
闪卡题干最多三行，截断题可点击读全文；答案完整滚动。编辑/讨论在卡片内部右上角；删除重复和底部大按钮，不加题答文字标签，以字重/细线区分。四向提示在可见卡片中央短暂显示，FSRS映射不变，阅读不评分。
Chat常态无“AI讨论”标题、模型/隐私说明排；右侧功能列表和独立新建。模型/历史/提示词/材料进二级列表；底部紧凑输入、添加、原生STT、发送/停止。历史需本地搜索/定位/安全删除与跨源恢复；首次介绍不能代替实际发送许可。
文档目标为接近Obsidian默认移动端阅读的统一排版及结构选材；Excalidraw、JSON Canvas、Mermaid/Markmap在本轮明确范围。复用成熟引擎，补格式/来源/权限适配，不复制闭源App、不重建全部插件平台；阅读扩展不授权复杂格式写回。

## 实现基线与下一施工

定稿重新读取的代码HEAD：`b7f5101187e37cffca87091bfd665eeaa94b9f59`；历史完整成功[Run 39443303363](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39443303363)，工作流`.github/workflows/public-ios-build.yml`。它只认证旧测试范围，不证明上面V1.1已交付；开工必须再查实际HEAD。
基线已有WCDB/FSRS、内容历史、Chat多会话/草稿、双目标Diff/状态/回执、ApprovedDraft、QA写/回读、撤销、来源核查及大量测试。不要把旧矩阵IN_PROGRESS当全部未开发。剩余P0是具体AI结论到建议、真正连续UI、异常恢复与反向最终证据。
顺序：G0核对→G1 Chat/闪卡/四Tab/历史原生实现→G2结构选材/全部明确格式→G3 P0-A～D及完整知识闭环→G4同SHA CI/证据/QA。不能只完成普通Markdown或漂亮界面就交付。

## 工程与数据安全

保留iOS26+、iPhone13、简繁英、App Light/Dark/System、DynamicType、集中ImpressV3Appearance/ImpressV3Language、Apple STT、通知、卡片三类型/独立解析/批量导入。只允许本任务必要内容依赖升级，先记录版本/许可/离线资源/设备性能，不顺带升级WCDB/FSRS。
V3 WCDB为卡片/FSRS/Chat唯一权威；内容revision与调度revision独立，恢复旧内容生成新版本。LearningEntry理解记录不冒充卡片旧答案。校准沿用现有LocalStore/计分器，不新增副本。
唯一V3 BackupCoordinator保留SQLite、理解记录、提示词与checkins的V1/V2兼容、校验/变更generation/恢复前镜像/冷启动恢复。普通ZIP**不加密**，可能包含已保存聊天/摘录；源Vault原件、私人ApprovedDraft/Recovery字节、书签、Key不入普通ZIP。缺快照不能假装可跨设备安全撤销，不能卸载/清库排查旧数据。
`ImVaultGuardedWrite.productionWriteEnabled = false`。只允许临时fixture或明确授权独立Debug `Impress-Write-Test-Vault`；本机回读不等于iCloud同步。模型内容不执行命令/SQL/路径，未授权不上传、不自动收费、不自动切换提供商。

## 验收与资料入口

[执行矩阵](REQUIREMENT_EXECUTION_MATRIX_20261020.md)保留85稳定ID与子项；[冒烟矩阵](SMOKE_TEST_MATRIX.md)保留ACCEPT-01～12、真实UI18步、故障注入及全回归；[差距审计](IMPLEMENTATION_GAP_AUDIT_20261020.md)区分已有基础/新缺口；[架构](KNOWLEDGE_LIFECYCLE_V1.md)规定引擎/来源/提案/恢复；[设备QA](VAULT_DEVICE_QA_V1.md)限定实际测试权限；[校准集成](CALIBRATION_V3_2_INTEGRATION.md)说明只恢复入口不解冻新规则。
构建/来源背景仍见[PUBLIC_BUILD_CONTRACT.md](PUBLIC_BUILD_CONTRACT.md)、[BUILD_AND_SIGN.md](BUILD_AND_SIGN.md)、`SOURCE_MANIFEST.json`，但旧分支/布局指示不能覆盖当前产品稿。
最终QA须绑定同一实际Git SHA、完整Core/原生XCTest、Debug/Release Simulator、ARM64、UI证据、IPA完整性及SHA-256。旧IPA不能称为新定稿版本；物理iPhone13、真实HTTP/Keychain、Files/iCloud分别验收。
公开源缺权威原版1024图标的历史限制仍须复核，禁止自行生成替换；无签名QA不等于正式发行或已安装。不得向公共仓库提交私人笔记、用户截图、Key、数据库、证书或未授权资源。当前文档提交没有新IPA。

## 2026-10-21 · V1.1 开发续作状态

指定分支 `feature/impress-duplex-loop-v1` 已实现 Excalidraw LZ-String compressed-json 解析、受限原生绘图视口/内嵌 PNG/JPEG、选材后逐版本的 Chat 门禁及 F03/F04 中断人工只读恢复判定。相关 Swift Core/XCTest 已增加。工程新增 `aReuImpress-iPhoneUITests` 真实 UI 测试 Target，并纳入主 Scheme；该测试目前仅覆盖四 Tab 跳转、真实屏幕截图和冷启动，**不等于原冒烟矩阵的 18 步业务 E2E**。Mermaid、Markmap、复合格式完整阅读、故障矩阵整体与同 SHA QA IPA 仍需验收。

继续用 `.github/workflows/public-ios-build.yml` 的 GitHub Actions 查看最新提交对应的独立 Swift Core、XCTest、Simulator、ARM64、未签名 IPA SHA-256。不得将旧 `39489025745` 的成功视为本次新代码交付。生产 Vault 写入始终禁用。

## 2026-10-22 · 阅读器专项施工证据

本轮只在 `feature/impress-duplex-loop-v1` 上施工。原有 MarkdownView 阅读层替换为一次初始化的受控离线 `WKWebView` 宿主，使用固定版本 `markdown-it 14.1.0` 与既有 Mermaid 11.12.2、Markmap 0.18.12 共享离线资源；支持 Markdown 语义列表和 Mermaid/Markmap 围栏的正文原位渲染，保留独立图形选材页。原生 Properties 使用 `ImpressFrontmatterReader` 提供类型化字段和 UTF8 偏移，只读、安全降级。原生 Canvas/Excalidraw 独立视图和 Chat 来源回读不变。

**本段是源码施工记录，不是验收完成声明。** 参见 SMOKE 的 RDR-01～12。复杂 YAML、笔记内 Canvas/Excalidraw 嵌入、外部附件及数学公式的完整支持仍需单独验证。真实 iPhone13 与 Obsidian 截图比对未完成；正式 Vault 写入门禁仍关闭。此后的 CI 必须绑定最终精确 SHA。
