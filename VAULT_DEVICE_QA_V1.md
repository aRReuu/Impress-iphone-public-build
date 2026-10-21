# Impress · V1.1 设备、复杂文档与受控写回 QA

> 产品权威：[PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。仅指定开发分支`feature/impress-duplex-loop-v1`。本次是QA规程定稿，不是已执行设备报告。物理iPhone13、真实Keychain/HTTP、Files/iCloud仍须独立证据。
> `ImVaultGuardedWrite.productionWriteEnabled = false`。Release不能修改正式Obsidian原件；Debug也不获日常Vault写权限。能显示/选择复杂文档不等于授权修改该格式。

## 1. 测试前置与禁止事项

只用自己构造的无隐私合成材料、独立测试数据库和完全可丢弃目录。不得将日常Vault改名用于测试，不上传本会话用户截图/私人笔记/数据库/Key/证书到公共仓库。没有真实设备就记录DEVICE_BLOCKED，不用模拟器冒充。
设备写测试须是用户以UIDocumentPicker明确授权的独立根目录，准确名为`Impress-Write-Test-Vault`；名称本身不是权限。书签/真实Vault身份、完整相对路径、目录边界/符号链接和源SHA必须同时有效。名称相近或另一个同名Vault不能借权限写入。
`commitFixture`仅temporaryDirectory；真实文件协调、iCloud和书签测试不能用fixture路径代替。Debug入口每次都需完整Diff与明确确认，不持久化全局写开关；Release拒绝写入。Excalidraw、Canvas的查看器保持只读，特殊`.excalidraw.md`不能被普通Markdown编辑器意外覆写。
确认安装包对应Git SHA、构建配置、Run和SHA-256；控制写回需要Debug ARM64测试包，Release编译/锁定验证另记。无签名IPA需要用户合法签名/侧载，不代表发行。原版AppIcon及缺失1024资源的限制如实记录，不生成替代图标。不要卸载/清空现有App排查数据。

## 2. 设备视觉与交互（新实现后执行，当前NOT_RUN）

笔记一级折叠树：核对根文件、多层目录、展开／收起与缩进，只显示名称和必要 chevron，不出现文件/文件夹装饰 Icon、路径／文摘副标题。搜索可找到折叠目录子孙并临时显示祖先，清空后恢复原折叠状态；重名文件不串路径，授权被撤销或换 Vault 后不出现旧文件；测试分批索引、120 条分页、源版本回读和只读安全门禁，使用合成 Vault。
四Tab：闪卡/笔记/校准器/设置；打开已有校准记录，通知与深链进入正确页面，不重算旧分、不恢复首页周图。
闪卡短题/超三行题/大字号最多三行；点击截断题可读完整原文且返回原卡，答案能触底。只有卡内右上编辑/讨论、无底部重复按钮/题答文字标签；揭示后细线与字重区分；中央评分提示清晰且取消不计分。选字、滚动、来源导航、打开编辑/Chat、图形平移缩放均不能误评分。
Chat无AI讨论标题/模型说明/常驻隐私段落；功能列表/新建顺序正确，二级模型/历史/提示词/材料可用。首次说明后不重复；范围/来源/服务商变更仍重批。键盘、多行增长/滚动、附件、STT/发送/停止、失败与返回草稿均实测。
历史页搜索全部本地标题/消息/来源并定位命中，跨源恢复不串材料。删除普通/当前/带未执行提案/已应用回执/中断会话，检查删除范围、保留回执仍可达和异步不复活；不删原卡/FSRS/原文件。旧ZIP恢复会带回旧聊天的边界明确告知。
覆盖简繁英、Light/Dark/System、系统字号、SafeArea、横向宽内容、VoiceOver和触控区域；网页跟随App手动主题，非只跟系统。保存原生截图/操作证据，仅合成内容；不能用离线HTML设计图替代实际App验收。

## 3. 复合文档“显示→选材→Chat→重开”

在笔记Tab连接测试目录，包含复杂Markdown、无标题/同名标题、BOM/CRLF、WikiLink/别名/块引用、嵌入/Callout/公式/表格/本地附件，另含Excalidraw普通/压缩封装、Canvas分组/文件subpath/连线、Mermaid与Markmap导图及未知模板块。
逐类核对图形真实显示、原布局/资源、目录/节点/分支范围、父子多选去重、实际材料预览与源版本。嵌入笔记各依赖分别列出；普通链接不自动拉全文，未选节点/图片区域不得发送。选定材料保存到Chat后重开必须仍有真实范围/身份，而非只保文件名。
无标题也可选段落/文字；重名标题与不同Vault不串错。代码/Frontmatter/模板里的伪标题不进入目录。缺件、未下载、撤权、循环引用、越界/符号链接、坏压缩/异常大资源局部失败，不执行脚本/模板，不暗中联网拉图片。
记录iPhone13首屏耗时、峰值内存、长文滚动、画布缩放、取消、后台恢复；大图按需激活，预览与源版本绑定。使用文本模型讨论图时明确只给了文字/结构；需要视觉理解另批准范围/提供商并验证模型能力，不能用本地预览冒充AI识图。
真实API只在设备有合法Keychain、明确使用/费用授权的情况下执行；当前不授权自动收费。无凭据使用合成响应，并准确标为Mock，不声称真实HTTP成功。

## 4. Debug QA Markdown写入与回读

1. 建立独立`Impress-Write-Test-Vault`，至少两篇合成Markdown，先本机Files，再按实际授权验证iCloud副本。文件目录名不是生产授权。
2. 从笔记Tab授权并读取源文件，核查来源/章节；通过现有私有草稿或指定AI回复形成局部可编辑建议。普通讨论/总结不修改文件。
3. 审阅完整未截断Diff、Vault身份/全路径、原始SHA、原cardID/contentRevision；允许仅笔记/仅卡片/两者，未选对象零改动。改变内容/目标后旧确认失效。
4. 明确确认后，在NSFileCoordinator写入期间重查真实SHA；写前保存受保护字节副本，成功写后再回读比对。原卡用当前FSRS调度CAS及已批准内容revision，保持cardID/历史。
5. UI显示各目标真实结果；Files/Obsidian打开测试副本及Impress重新读取核对。只有本机回读成功不能声明iCloud已同步；服务器/其他设备另验。
6. 负向测试改用另一份合成非QA目录、同名不同Vault、过期书签、外部改文、移动/删文件、权限撤销；必须拒写并保留草稿，不在缓存路径凭空重建原件。
7. Release/生产写门禁拒绝；撤销同样不能绕过。保持完整BOM/CRLF/Frontmatter/WikiLink/未改区域，混合换行不能被隐瞒为无变化。

根本状态区别：草稿已存≠原文件更新；内容未变不造版本；内容已存在不重复写；测试副本已写且回读≠正式Vault更新≠iCloud同步。不能以统一“保存成功”代替逐目标回执。

## 5. 来源核查、异常和安全撤销

按SMOKE F01～F13执行双向部分成功、文件已写回执未存、DB已改状态未存、重复确认/已应用重试、执行中强杀、两次连续修改、旧撤销遇新内容、仅FSRS评分前进、授权/移动/SHA变化、快照污染、旧数据恢复与删除并发。
重启不自动正向/反向重播；成功事实保留，失败目标重新核查与批准。两次批准的ApprovedDraft各自不可变；旧收据Diff不依赖新活动草稿。撤销需完整反向Diff/确认，冲突拒盖后来的合法修改，合法逆序可恢复原始字节。
源相关章节变化后从笔记找到原卡，直接修订或明确不影响；无改动保存不能假确认。无关/可安全判定排版变化不干扰，相关/重复/失效定位如实说明。后来合法原卡不得被旧笔记覆盖；正常FSRS评分不导致假内容冲突。

## 6. 备份恢复与隐私范围

仅使用现有V3备份。核查cardID/内容版本/FSRS事件、多会话/消息、草稿/模型/提示词、待确认提案、部分成功回执及旧格式兼容；同设备重启、旧ZIP/新ZIP恢复、恢复中断分别测试。保护恢复前镜像，防SQLite/WAL与JSON混时代；失败不清库。
普通ZIP未加密且可含已保存聊天/批准摘录，必须告知；**完整源Markdown、私人ApprovedDraft/Recovery字节、Key、书签不加入普通ZIP**。异机/卸载后缺原字节时禁文件撤销，不以聊天文本伪造恢复成功；备份有回执不等于有原始字节。不要为补备份创建第二套云同步。

## 7. 设备验收记录

每个场景记录Requirement/子项/ACCEPT、精确源码SHA、Actions Run、安装包SHA-256、Debug或Release、设备/系统/语言/主题/字号、测试文件/来源身份、操作步骤、实际结果及证据、失败/未执行/外部原因。不记录真实Key或私人正文。
真机/真实推理/Files/iCloud与模拟器/Core/XCTest分层；当前均未因定稿获得PASS。正式生产Vault仍锁定，不把后续单独授权评估当本轮发布前必须擅自执行的任务。

## 2026-10-21 · 复合格式与设备验证边界

Excalidraw 仅从当前授权文档读取合法受限数据，外部图片、SVG、脚本和插件不执行；内嵌 PNG/JPEG 按尺寸/字节数上限读取，Chat 只收到经审查的结构范围。中断应用核验只回读批准快照和精确 SHA / cardID 内容版本，不重复文件或 WCDB 写入。测试写权限仍严格限定临时 Fixture 或明确授权的独立 Debug QA Vault；`ImVaultGuardedWrite.productionWriteEnabled = false` 永久不变。

四 Tab/冷启动 XCUITest 不证明真实 Files/iCloud、设备 Keychain、签名、STT、提供商 HTTP 或 iPhone13 UI 性能。上述继续标记 DEVICE_BLOCKED/NOT_RUN，待具备明确的设备授权后独立验收；本轮无真实日常 Vault 文件写入。

## 2026-10-22 · W01–W15 校准器 Widget 真机签名与桌面验证

这是**必须由具备实际 iPhone13、签名权限及系统 Widget UI 的执行者完成**的外部门禁，不能用 CI 模拟器通过、静态 entitlement plist 或改掉 Widget 空态字样代替。App 与 Widget 复用同一 `CalibrationCartesianTrendRenderer`，账本仅为主 App 的 `checkins-v1.json`；App Group 里的 `calibration-widget-v1.json` 是最小只读投影而非第二份业务数据库。

1. 在 GitHub Actions 选择 `feature/impress-duplex-loop-v1` **最后一个完整成功 SHA** 的 `impress-v3-p0p2-unsigned-iphoneos-and-evidence` Artifact，校对 `build-evidence.json`、`IPA_SHA256.txt`、IPA 文件与打包内 `PlugIns/ImpressCalibrationWidgets.appex/ImpressCalibrationWidgets` 的存在和 arm64。不得拿旧 SHA 的包验收新 UI。
2. **对主 App 和 Widget Extension 分别签名**。分发 profile/签名必须分别具备合法有效的相同 App Group `group.areu.impress`，且 Widget Bundle ID 与扩展的嵌入关系匹配。只在源代码的两个 `.entitlements` 文件里写同一个字符串并不能证明重签名后的 IPA 真的获得 iOS 授权。部分免费 Personal Team / 侧载配置可能不支持这一能力；若被剥离，只能记 `DEVICE_BLOCKED / SIGNING_ENTITLEMENT_MISSING`，**不能在 App 层改为跨沙箱读取、关掉签名检查或伪造图表**。
3. 具备受信 Mac 的验收者可以解压**已重签名**的 IPA，通过 `codesign -d --entitlements :-` 分别查看 `Payload/aReuImpress-iPhone.app` 与 `Payload/aReuImpress-iPhone.app/PlugIns/ImpressCalibrationWidgets.appex` 的真实签名 entitlement，再查看对应有效 provisioning profile 的授权 App Group。不具备 Mac 的 Windows 侧载验收应使用签名工具自身提供的 Extension/Entitlement 报告和设备运行证据；无法读取签名不能冒充已核查。
4. 真机安装后，打开「校准器」而不是只打开 Widget，观察是否出现“桌面组件无法访问共享存储”的诊断。若出现，先处理上述合法签名/App Group 问题。若快照缺失，则重新进入校准器触发权威账本投影和 Widget Timeline 刷新；系统调度更新并不承诺同步瞬时完成。
5. 不删除真实旧数据的前提下，使用无隐私的独立测试数据完成五指标中其中一项的明确评估，记录主 App 的今日覆盖率；依次添加周/月/年各 Small、Medium 共**六个原生桌面 Widget**。每种实际查看二维坐标轴、Y 零线、灰色净分/蓝色均线、未评估日期断线、文字不溢出、今日 `x/5` / 月天数 / 年月覆盖，分别截图 Light/Dark 及简繁英组合。空数据可显示 `0/5` 与空坐标，不得变成负分或捏造数据。
6. 点击周/月/年组件，确认**进入同一个校准器 Tab 且保持对应周期**；返回桌面、杀进程重启、跨本地零点/时区测试合法刷新与路由。之后再分开验证备份恢复后重新投影、文件授权撤销以及通知不互相劫持。
7. 逐项记录用户授权设备的 iOS 版本、实际签名配置、主 App/Extension entitlement（**不要贴私钥/完整 profile**）、Git SHA、IPA 文件 SHA-256、测试日期、六布局原生截图、复现步骤和结果。没有这些证据时 W01–W15 只能 `CODE_DONE` 或 `SIMULATOR_PASS`，不能升 `DEVICE_PASS`。

真实 iPhone13 的 STT 麦克风、Files/iCloud 实际权限、Keychain/OpenCode Free HTTPS 和正式 Vault 安全限制仍是其它独立验收项；不能因为 Widget 恢复显示就一并标绿。
