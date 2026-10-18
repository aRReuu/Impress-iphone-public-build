//
//  ColorConstants.swift
//  CBDemo
//
//  Created by aReu on 2018/11/26.
//  Copyright © 2018年 aReu. All rights reserved.
//

import UIKit


// MARK: - 一级通用色调

/// 背景颜色 - 主背景色，使用系统分组背景色，自动适配暗黑/白天模式
let bgColor = UIColor.systemGroupedBackground

/// 次要背景颜色 - 用于section背景等次要背景
let secondaryBgColor = UIColor.secondarySystemGroupedBackground

/// 标题颜色 - 主要标题文字，自动适配暗黑/白天模式
let titleColor = UIColor.label

/// 文本内容颜色 - 主要内容文字
let contentColor = UIColor.secondaryLabel

/// 次标题颜色 - 次要标题文字
let subTitleColor = UIColor.tertiaryLabel

/// 占位符颜色 - 用于输入框占位符等
let placeholderColor = UIColor.placeholderText

///  重要事项 - 重要提醒颜色
let reviewCellColor = UIColor.systemRed

///  功能按钮颜色 - 主要功能按钮颜色
let funBtnColor = UIColor.systemBlue

/// 安全提示颜色 - 成功、安全状态提示
let safeTipColor = UIColor.systemGreen

/// 高亮颜色提醒 - 高亮显示颜色
let highlightColor = UIColor.systemYellow


// MARK: - 单元格颜色

/// 单元格背景颜色 - 用于cell背景，创建透明感官效果
let tableViewBGColor = UIColor.tertiarySystemGroupedBackground

/// 分割线颜色 - 表格分割线颜色
let separatorColor = UIColor.separator


// MARK: - 系统填充颜色

/// 系统填充色 - 用于细小形状的填充
let systemFillColor = UIColor.systemFill

/// 次要系统填充色 - 用于中等大小形状的填充
let secondarySystemFillColor = UIColor.secondarySystemFill

/// 三级系统填充色 - 用于大形状的填充（如输入框、按钮）
let tertiarySystemFillColor = UIColor.tertiarySystemFill

/// 四级系统填充色 - 用于包含复杂内容的大区域填充
let quaternarySystemFillColor = UIColor.quaternarySystemFill


// MARK: - 语义化颜色扩展

/// 搜索栏背景色 - 毛玻璃效果背景
let searchBarBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)

/// 搜索栏边框色 - 轻微边框增强视觉层次
let searchBarBorderColor = UIColor.separator.withAlphaComponent(0.5)

/// 空状态图标色 - 空状态图标的强调色
let emptyStateIconColor = UIColor.systemBlue.withAlphaComponent(0.6)

/// 滚动按钮背景色 - 滚动按钮的半透明背景
let scrollButtonBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)

/// 消息气泡阴影色 - 消息气泡的阴影效果
let messageBubbleShadowColor = UIColor.black.withAlphaComponent(0.1)

/// 导航栏模糊背景色 - 导航栏的毛玻璃效果
let navigationBarBlurColor = UIColor.systemBackground.withAlphaComponent(0.95)

/// 高亮搜索结果色 - 搜索结果的高亮颜色
let searchHighlightColor = UIColor.systemYellow.withAlphaComponent(0.3)

/// 下划线颜色 - 消息下划线的颜色
let underlineColor = UIColor.systemBlue.withAlphaComponent(0.8)

/// 占位符图标色 - 各种占位符图标的颜色
let placeholderIconColor = UIColor.systemGray2

/// 交互反馈色 - 按钮点击等交互的反馈颜色
let interactionFeedbackColor = UIColor.systemBlue.withAlphaComponent(0.1)

/// 占位符背景色 - 用于占位符图片的背景色
let placeholderBackgroundColor = UIColor.systemGray.withAlphaComponent(0.1)

/// 按钮图标透明度 - 按钮图标的透明度
let buttonIconAlpha: CGFloat = 0.8

/// 高亮透明度 - 搜索高亮等透明度
let highlightAlpha: CGFloat = 0.3

/// 阴影颜色 - 统一阴影颜色
let shadowColor = UIColor.black.withAlphaComponent(0.1)

/// 毛玻璃背景色 - 深色毛玻璃效果
let darkBlurBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)

/// 半透明黑色背景 - 用于遮罩层
let semiTransparentBlack = UIColor.black.withAlphaComponent(0.5)

/// 播放按钮颜色 - 音频播放按钮的系统橙色
let playBtnColor = UIColor.systemOrange


// MARK: - Native V3 control configurations (iOS 15+)
// These are content-layer controls. Liquid Glass belongs to system navigation,
// not to every card/background. UIKit supplies pressed/disabled states.
@available(iOS 15.0, *)
enum ImpressV3NativeButtonAppearance {
    /// A filled action is reserved for the one primary step in a workflow.
    static func primary(_ button: UIButton, title: String) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.buttonSize = .large
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12, leading: 18, bottom: 12, trailing: 18)
        configuration.baseBackgroundColor = ImpressV3Appearance.accent
        configuration.baseForegroundColor = ImpressV3Appearance.primaryButtonText
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            attributes in
            var next = attributes
            next.font = ImpressV3Appearance.Typography.heading
            return next
        }
        button.configuration = configuration
        prepare(button, minimumHeight: ImpressV3Appearance.Metrics.primaryActionHeight)
    }

    /// Quiet, monochromatic review primary action. Reserve brand accent for
    /// navigation and selection; no full-width saturated colored pill.
    static func reviewPrimary(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 12, leading: 20, bottom: 12, trailing: 20)
        config.baseBackgroundColor = ImpressV3Appearance.reviewPrimarySurface
        config.baseForegroundColor = ImpressV3Appearance.reviewPrimaryInk
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            value in
            var output = value
            output.font = ImpressV3Appearance.Typography.body
            return output
        }
        button.configuration = config
        prepare(button, minimumHeight: ImpressV3Appearance.Metrics.primaryActionHeight)
    }

    /// Two compact native controls shown only after answer reveal.
    /// No stroke, shadow, gradients, custom bitmap icons or extra footer rows.
    static func reviewSecondary(_ button: UIButton, title: String, symbol: String) {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = ImpressV3Appearance.Metrics.symbolGap
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 10, leading: 13, bottom: 10, trailing: 13)
        config.baseBackgroundColor = ImpressV3Appearance.reviewActionSurface
        config.baseForegroundColor = ImpressV3Appearance.primaryText
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            value in
            var output = value
            output.font = ImpressV3Appearance.Typography.supporting
            return output
        }
        button.configuration = config
        prepare(button, minimumHeight: ImpressV3Appearance.Metrics.tapTarget)
    }

    /// Lightweight tertiary actions in the compact review toolbar.
    static func secondary(_ button: UIButton, title: String) {
        button.configuration = secondaryConfiguration(title: title)
        prepare(button, minimumHeight: ImpressV3Appearance.Metrics.tapTarget)
    }

    static func secondaryConfiguration(title: String, symbol: String? = nil)
    -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.buttonSize = .large
        configuration.cornerStyle = .large
        configuration.baseForegroundColor = ImpressV3Appearance.accent
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 10, leading: 8, bottom: 10, trailing: 8)
        if let symbol {
            configuration.image = UIImage(systemName: symbol)
            configuration.imagePadding = ImpressV3Appearance.Metrics.symbolGap
        }
        return configuration
    }

    /// Quiet, tangible secondary buttons (file/photo/add option).
    /// These are not Liquid Glass and have no decorative stroke or shadow.
    static func quiet(_ button: UIButton, title: String, symbol: String? = nil) {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.buttonSize = .large
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = ImpressV3Appearance.quietControlSurface
        configuration.baseForegroundColor = ImpressV3Appearance.primaryText
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12, leading: 12, bottom: 12, trailing: 12)
        if let symbol {
            configuration.image = UIImage(systemName: symbol)
            configuration.imagePadding = ImpressV3Appearance.Metrics.symbolGap
        }
        button.configuration = configuration
        prepare(button, minimumHeight: ImpressV3Appearance.Metrics.controlHeight)
    }

    private static func prepare(_ button: UIButton, minimumHeight: CGFloat) {
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        if !button.constraints.contains(where: {
            $0.firstAttribute == .height &&
            $0.secondItem == nil &&
            $0.relation == .greaterThanOrEqual &&
            $0.constant >= minimumHeight
        }) {
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight).isActive = true
        }
    }
}


// MARK: - Impress V3 design authority
// This file is the SINGLE source for color, font roles, surface hierarchy,
// radius and button treatment in native Impress V3 screens. UIKit owns the
// system navigation/tab materials. Semantic UIColors follow Light/Dark Mode.
// Never create shadow copies of these values inside individual controllers.
enum ImpressV3Appearance {
    /// One persisted preference for the entire UIKit window hierarchy.
    /// By default, unspecified delegates appearance to the operating system.
    enum Mode: String, CaseIterable {
        case system, light, dark
        var title: String {
            switch self {
            case .system: return V3L("跟随系统")
            case .light: return V3L("浅色")
            case .dark: return V3L("深色")
            }
        }
        var interfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .system: return .unspecified
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    static let modeStorageKey = "ImpressV3AppearanceMode"

    static func selectedMode(in defaults: UserDefaults = .standard) -> Mode {
        Mode(rawValue: defaults.string(forKey: modeStorageKey) ?? "") ?? .system
    }

    @MainActor
    static func applyAppearance(to window: UIWindow?, defaults: UserDefaults = .standard) {
        window?.overrideUserInterfaceStyle = selectedMode(in: defaults).interfaceStyle
    }

    @MainActor
    static func setAppearance(_ mode: Mode, defaults: UserDefaults = .standard,
                              windows: [UIWindow]? = nil) {
        defaults.set(mode.rawValue, forKey: modeStorageKey)
        let targets = windows ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for window in targets {
            window.overrideUserInterfaceStyle = mode.interfaceStyle
        }
    }

    // Native grouped canvas under all primary screens and the floating TabBar.
    // The slightly elevated surface belongs to content, input and grouped rows.
    static let page = UIColor.systemGroupedBackground
    static let surface = UIColor.secondarySystemGroupedBackground
    // Segments keep a visible track without faux glass or custom shadow art.
    static let segmentTrack = UIColor.tertiarySystemFill
    static let secondarySegmentSelection = UIColor.tertiarySystemGroupedBackground
    static let mutedAction = UIColor.systemGray
    static let quietControlSurface = UIColor.secondarySystemFill
    static let reviewActionSurface = UIColor.tertiarySystemGroupedBackground
    static let reviewPrimarySurface = UIColor.label
    static let reviewPrimaryInk = UIColor.systemBackground
    static let reviewOverlaySurface = UIColor { traits in
        UIColor.secondarySystemGroupedBackground.resolvedColor(with: traits)
            .withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.97 : 0.95)
    }
    static let reviewOverlaySymbol = UIColor.secondaryLabel
    static let optionSurface = UIColor.tertiarySystemGroupedBackground
    // Semantic colors already track the system theme. Feedback fills must
    // also resolve their alpha in the active trait (not cache light RGB).
    // Dark mode uses slightly more opacity so the state remains visible
    // against elevated card surfaces without adding hard strokes.
    private static func feedbackSurface(_ base: UIColor) -> UIColor {
        UIColor { traits in
            base.resolvedColor(with: traits)
                .withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.22 : 0.12)
        }
    }
    static let selectedOptionSurface = feedbackSurface(funBtnColor)
    static let correctOptionSurface = feedbackSurface(safeTipColor)
    static let incorrectOptionSurface = feedbackSurface(reviewCellColor)
    static let accent = funBtnColor
    static let primaryText = titleColor
    static let secondaryText = contentColor
    static let mutedText = subTitleColor
    static let divider = separatorColor
    static let positive = safeTipColor
    static let caution = UIColor.systemOrange
    static let negative = reviewCellColor
    static let timelineInactive = UIColor.systemGray2
    // iOS systemBlue is brighter on dark surfaces; white-on-bright-blue
    // becomes lower contrast. A dynamic on-accent role handles both themes.
    // Segments and filled action buttons reuse this same semantic foreground.
    static let primaryButtonText = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
    }
    static let imagePreviewBackdrop = UIColor { traits in
        let base: UIColor = traits.userInterfaceStyle == .dark ? .black : .white
        return base.withAlphaComponent(0.94)
    }

    /// CSS is required because MarkdownView wraps a bundled WKWebView whose
    /// vendor stylesheet fixes white backgrounds and dark ink. UIKit dynamic
    /// UIColors do not penetrate HTML. CSS media queries switch in place as
    /// the iPhone system appearance changes; do NOT touch third-party Pods,
    /// reload user notes or inject CSS into the external DeepSeek website.
    /// Only trusted static CSS is injected into the local read-only Markdown.
    static let markdownReaderCSS: String = """
    :root {
      color-scheme: light dark;
      --im-paper: #FFFFFF;
      --im-ink: #1C1C1E;
      --im-muted: #54545A;
      --im-border: #D1D1D6;
      --im-code: #F2F2F7;
      --im-link: #0064CB;
      --im-accent-quote: #8E8E93;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --im-paper: #1C1C1E;
        --im-ink: #F2F2F7;
        --im-muted: #AEAEB2;
        --im-border: #48484A;
        --im-code: #2C2C2E;
        --im-link: #72B7FF;
        --im-accent-quote: #98989D;
      }
    }
    html, body, .container, .markdown-body {
      background: var(--im-paper) !important;
      color: var(--im-ink) !important;
      -webkit-text-size-adjust: 100%;
    }
    .markdown-body h1, .markdown-body h2, .markdown-body h3,
    .markdown-body h4, .markdown-body h5, .markdown-body h6,
    .markdown-body p, .markdown-body li {
      color: var(--im-ink) !important;
    }
    .markdown-body a, .markdown-body a:visited {
      color: var(--im-link) !important;
    }
    .markdown-body pre, .markdown-body code, .markdown-body tt,
    .markdown-body .highlight {
      color: var(--im-ink) !important;
      background-color: var(--im-code) !important;
    }
    .markdown-body pre code {
      background: transparent !important;
    }
    .markdown-body table tr,
    .markdown-body table tr:nth-child(2n),
    .markdown-body table th, .markdown-body table td {
      background-color: var(--im-paper) !important;
      color: var(--im-ink) !important;
      border-color: var(--im-border) !important;
    }
    .markdown-body blockquote {
      color: var(--im-muted) !important;
      border-left-color: var(--im-accent-quote) !important;
    }
    .markdown-body hr {
      background-color: var(--im-border) !important;
      border-color: var(--im-border) !important;
    }
    body {
      margin: 0 !important;
      font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
    }
    .markdown-body {
      box-sizing: border-box; max-width: 760px; margin: 0 auto !important;
      padding: 24px 20px 44px !important; font-size: 17px;
      line-height: 1.7; overflow-wrap: anywhere; letter-spacing: -0.1px;
    }
    .markdown-body h1, .markdown-body h2, .markdown-body h3 {
      line-height: 1.32; letter-spacing: -0.35px;
      margin-top: 1.45em; margin-bottom: 0.7em;
    }
    .markdown-body h1:first-child, .markdown-body h2:first-child {
      margin-top: 0.15em;
    }
    .markdown-body p, .markdown-body ul, .markdown-body ol { margin-bottom: 1em; }
    .markdown-body blockquote { margin: 1.2em 0; padding: 0.3em 1em; border-left-width: 2px; }
    .markdown-body pre { padding: 14px !important; border-radius: 10px; overflow-x: auto; }
    .markdown-body img { max-width: 100%; height: auto; border-radius: 8px; }
    .markdown-body table { width: 100%; display: block; overflow-x: auto; }
    """

    /// Apply only tint colors; never paint over iOS 26+ floating Liquid Glass.
    /// The TabBar's content backdrop comes from the controller's page color.
    static func styleTabBar(_ bar: UITabBar) {
        bar.tintColor = accent
        bar.unselectedItemTintColor = secondaryText
    }

    static func styleNavigationBar(_ bar: UINavigationBar) {
        bar.tintColor = accent
    }

    /// Native segmented control with an unmistakable selected state.
    /// Primary type selection is prominent; single/multiple choice stays quiet.
    /// This method is the sole owner of segment color, font and corner style.
    static func styleSegmentedControl(_ control: UISegmentedControl,
                                      prominent: Bool) {
        control.backgroundColor = segmentTrack
        control.selectedSegmentTintColor = prominent ? accent : secondarySegmentSelection
        control.apportionsSegmentWidthsByContent = false
        control.setTitleTextAttributes([
            .font: Typography.supporting,
            .foregroundColor: primaryText
        ], for: .normal)
        control.setTitleTextAttributes([
            .font: Typography.heading,
            .foregroundColor: prominent ? primaryButtonText : primaryText
        ], for: .selected)
        control.layer.cornerRadius = Radius.segment
        // Keep Apple's intrinsic segment geometry and pressed-state behavior.
        // An outer hard border would reintroduce the heavy boxed-button look.
        control.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Metrics.segmentHeight).isActive = true
    }

    /// Fill the available width on an iPhone, but stop before segments turn
    /// into wide tiles on iPad/landscape. A soft fill constraint lets the
    /// required maximum take precedence, without unsatisfiable constraints.
    static func segmentedRow(_ control: UISegmentedControl, compact: Bool = false) -> UIView {
        let container = UIView()
        control.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(control)
        let maxWidth = compact ? Metrics.compactSegmentWidth : Metrics.maximumSegmentWidth
        let fill = control.widthAnchor.constraint(equalTo: container.widthAnchor)
        fill.priority = .defaultHigh
        NSLayoutConstraint.activate([
            control.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            control.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            control.topAnchor.constraint(equalTo: container.topAnchor),
            control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            control.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            control.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            fill
        ])
        return container
    }

    /// Semantic measurements: iPhone 13 and larger Dynamic Type remain legible.
    /// Visual sizing MUST NOT be redefined in individual V3 controllers.
    enum Metrics {
        static let screenInset: CGFloat = 20
        static let compactInset: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let rowSpacing: CGFloat = 10
        static let choiceSpacing: CGFloat = 10
        static let symbolGap: CGFloat = 8
        static let tapTarget: CGFloat = 44
        static let controlHeight: CGFloat = 48
        static let segmentHeight: CGFloat = 50
        static let primaryActionHeight: CGFloat = 52
        static let reviewOverlayBadgeHeight: CGFloat = 44
        static let reviewOverlaySymbolSize: CGFloat = 17
        static let answerOptionHeight: CGFloat = 52
        static let maximumSegmentWidth: CGFloat = 440
        static let compactSegmentWidth: CGFloat = 320
        static let cardInset: CGFloat = 16
        static let fieldPadding: CGFloat = 14
        static let optionTextPadding: CGFloat = 14
        static let questionEditorMinHeight: CGFloat = 100
        static let answerEditorMinHeight: CGFloat = 128
        static let photoPreviewHeight: CGFloat = 220
        static let batchEditorMinHeight: CGFloat = 260
        static let promptEditorMinHeight: CGFloat = 230
        static let timelineRailWidth: CGFloat = 1
        static let timelineDotDiameter: CGFloat = 10
        static let timelineRailOffset: CGFloat = 27
        static let timelineTextOffset: CGFloat = 51
        static let speechPreviewMinHeight: CGFloat = 130
        static let noteRowEstimatedHeight: CGFloat = 68
        static let noteReaderVerticalInset: CGFloat = 24
        static let noteReaderHorizontalInset: CGFloat = 20
    }

    enum ChoiceFeedback {
        case idle, selected, correct, incorrect
    }

    /// One reusable answer treatment for the active V3 review view.
    /// A rounded inset surface is enough: never add per-answer heavy borders.
    static func styleChoiceOption(_ button: UIButton, feedback: ChoiceFeedback) {
        let fill: UIColor
        switch feedback {
        case .idle: fill = optionSurface
        case .selected: fill = selectedOptionSurface
        case .correct: fill = correctOptionSurface
        case .incorrect: fill = incorrectOptionSurface
        }
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.title = button.title(for: .normal) ?? button.configuration?.title
            configuration.buttonSize = .large
            configuration.cornerStyle = .large
            configuration.titleAlignment = .leading
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: 12, leading: Metrics.optionTextPadding,
                bottom: 12, trailing: Metrics.optionTextPadding)
            configuration.imagePadding = Metrics.symbolGap
            configuration.baseForegroundColor = primaryText
            configuration.background.backgroundColor = fill
            switch feedback {
            case .idle: break
            case .selected, .correct:
                configuration.image = UIImage(systemName: "checkmark.circle.fill")
            case .incorrect:
                configuration.image = UIImage(systemName: "xmark.circle.fill")
            }
            configuration.titleTextAttributesTransformer =
                UIConfigurationTextAttributesTransformer { attributes in
                    var next = attributes
                    next.font = Typography.body
                    return next
                }
            button.configuration = configuration
        } else {
            button.backgroundColor = fill
            button.setTitleColor(primaryText, for: .normal)
            button.titleLabel?.font = Typography.body
            button.layer.cornerRadius = Radius.field
        }
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.adjustsFontForContentSizeCategory = true
    }

    static func styleGroupedCell(_ cell: UITableViewCell) {
        cell.backgroundColor = surface
    }

    static func styleGroupedTable(_ table: UITableView) {
        table.backgroundColor = page
        table.separatorStyle = .singleLine
        table.separatorColor = divider
        table.cellLayoutMarginsFollowReadableWidth = true
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = Metrics.noteRowEstimatedHeight
    }

    static func styleVaultDocument(_ view: UIView) {
        view.backgroundColor = surface
        view.layer.cornerRadius = Radius.card
        view.layer.masksToBounds = true
    }

    static var vaultSourceInsets: UIEdgeInsets {
        UIEdgeInsets(top: Metrics.noteReaderVerticalInset,
                     left: Metrics.noteReaderHorizontalInset,
                     bottom: Metrics.noteReaderVerticalInset,
                     right: Metrics.noteReaderHorizontalInset)
    }

    static func styleReadingTextView(_ textView: UITextView) {
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = surface
        textView.textColor = primaryText
        textView.font = Typography.body
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = vaultSourceInsets
        textView.layer.cornerRadius = Radius.card
        textView.layer.masksToBounds = true
    }

    /// Respect the original iOS 14 deployment floor. Native UIButton.Configuration
    /// applies on iOS 15+, with one centralized conventional fallback.
    static func styleQuietButton(_ button: UIButton, title: String, symbol: String? = nil) {
        if #available(iOS 15.0, *) {
            ImpressV3NativeButtonAppearance.quiet(button, title: title, symbol: symbol)
        } else {
            button.setTitle(title, for: .normal)
            if let symbol { button.setImage(UIImage(systemName: symbol), for: .normal) }
            button.tintColor = primaryText
            button.backgroundColor = quietControlSurface
            button.titleLabel?.font = Typography.body
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.layer.cornerRadius = Radius.field
            button.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Metrics.controlHeight).isActive = true
        }
    }

    static func styleTextField(_ field: UITextField) {
        field.borderStyle = .none
        field.backgroundColor = surface
        field.textColor = primaryText
        field.font = Typography.body
        field.adjustsFontForContentSizeCategory = true
        field.layer.cornerRadius = Radius.field
        let inset = UIView(frame: CGRect(
            x: 0, y: 0, width: Metrics.fieldPadding, height: 1))
        field.leftView = inset
        field.leftViewMode = .always
    }

    enum Radius {
        static let card: CGFloat = 16
        static let segment: CGFloat = 12
        static let field: CGFloat = 12
        static let compactField: CGFloat = 10
        static let timelineNode: CGFloat = 5
    }

    /// Prefer semantic text roles and Dynamic Type. Views that own text must
    /// continue to opt in to adjustsFontForContentSizeCategory.
    enum Typography {
        static var largeTitle: UIFont { UIFont.preferredFont(forTextStyle: .title1) }
        static var cardTitle: UIFont { UIFont.preferredFont(forTextStyle: .title3) }
        static var heading: UIFont { UIFont.preferredFont(forTextStyle: .headline) }
        static var body: UIFont { UIFont.preferredFont(forTextStyle: .body) }
        static var supporting: UIFont { UIFont.preferredFont(forTextStyle: .subheadline) }
        static var footnote: UIFont { UIFont.preferredFont(forTextStyle: .footnote) }
        static var caption: UIFont { UIFont.preferredFont(forTextStyle: .caption1) }
        static var micro: UIFont { UIFont.preferredFont(forTextStyle: .caption2) }
        static var code: UIFont {
            UIFontMetrics(forTextStyle: .body).scaledFont(
                for: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular))
        }
        static var compactCode: UIFont {
            UIFontMetrics(forTextStyle: .footnote).scaledFont(
                for: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular))
        }
    }
}


// MARK: - Impress V3.2 localized UI copy (never localize user documents)
//
// Language is an app-scoped choice, independent of iOS system preferences.
// All product-owned translations live here; stored user text is never touched.
enum ImpressV3Language: String, CaseIterable {
    case simplified = "zh-Hans"
    case traditional = "zh-Hant"
    case english = "en"

    static let storageKey = "ImpressV3UILanguage"
    static let didChange = Notification.Name("ImpressV3UILanguageDidChange")

    var title: String {
        switch self {
        case .simplified: return "简体中文"
        case .traditional: return "繁體中文"
        case .english: return "English"
        }
    }

    static func selected(in defaults: UserDefaults = .standard) -> ImpressV3Language {
        guard let raw = defaults.string(forKey: storageKey),
              let language = ImpressV3Language(rawValue: raw) else {
            return .simplified
        }
        return language
    }

    @MainActor
    static func change(to language: ImpressV3Language,
                       defaults: UserDefaults = .standard) {
        guard selected(in: defaults) != language else { return }
        defaults.set(language.rawValue, forKey: storageKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    private static let translations: [String: (traditional: String, english: String)] = [
        "闪卡": ("閃卡", "Flashcards"),
        "校准": ("校準", "Calibration"),
        "设置": ("設定", "Settings"),
        "笔记": ("筆記", "Notes"),
        "卡片集": ("卡片集", "Card Library"),
        "外观": ("外觀", "Appearance"),
        "显示模式": ("顯示模式", "Appearance Mode"),
        "跟随系统": ("跟隨系統", "System"),
        "浅色": ("淺色", "Light"),
        "深色": ("深色", "Dark"),
        "语言": ("語言", "Language"),
        "应用语言": ("應用語言", "App Language"),
        "简体中文": ("簡體中文", "Simplified Chinese"),
        "繁体中文": ("繁體中文", "Traditional Chinese"),
        "英语": ("英文", "English"),
        "英文": ("英文", "English"),
        "内容工具": ("內容工具", "Content Tools"),
        "提示词": ("提示詞", "Prompts"),
        "学习节奏": ("學習節奏", "Study Routine"),
        "复习通知": ("複習通知", "Review Notifications"),
        "数据安全": ("資料安全", "Data Safety"),
        "数据与备份": ("資料與備份", "Data & Backup"),
        "费曼总结、选择题、问题与答案 · 可建立多份自定义模板": ("費曼總結、選擇題、問題與答案 · 可建立多份自訂範本", "Feynman summaries, quizzes, and custom prompts"),
        "关闭、到期提醒或每日习惯提醒": ("關閉、到期提醒或每日習慣提醒", "Off, due-card, or daily reminders"),
        "静默自动备份、iCloud 副本与受控恢复": ("靜默自動備份、iCloud 副本與受控還原", "Local snapshots, iCloud copies, and safe restore"),
        "跟随系统、浅色或深色": ("跟隨系統、淺色或深色", "System, Light, or Dark"),
        "简体中文、繁体中文或英文": ("簡體中文、繁體中文或英文", "Simplified Chinese, Traditional Chinese, or English"),
        "本地模板仅在用户明确操作后复制，不自动上传私人内容。": ("本機範本僅在使用者明確操作後複製，不自動上傳私人內容。", "Templates stay on device and are never uploaded automatically."),
        "FSRS-6 决定到期时间；通知仅负责提醒。": ("FSRS-6 決定到期時間；通知僅負責提醒。", "FSRS-6 schedules reviews; notifications only remind you."),
        "默认跟随系统；手动选择仅影响 Impress，不修改 iPhone 系统外观。": ("預設跟隨系統；手動選擇僅影響 Impress，不修改 iPhone 系統外觀。", "Defaults to System. Changes apply to Impress, not your iPhone."),
        "默认跟随系统；手动选择仅影响本应用，重启后保留。": ("預設跟隨系統；手動選擇僅影響本應用，重新啟動後保留。", "System is the default. Your choice persists across launches."),
        "备份保存在本机；连接 iCloud Drive 文件夹后可自动创建副本。": ("備份儲存在本機；連接 iCloud Drive 資料夾後可自動建立副本。", "Backups stay on device until you authorize an iCloud Drive folder."),
        "显示语言只改变界面文本，不会翻译或修改你保存的卡片、笔记和历史。": ("顯示語言只改變介面文字，不會翻譯或修改已儲存的卡片、筆記及歷史。", "Changing the language never translates or modifies your cards, notes, or history."),
        "跟随系统是默认选项。浅色或深色仅对本 App 生效，并在重新启动后保留。": ("跟隨系統是預設選項。淺色或深色僅對本 App 生效，重新啟動後仍會保留。", "System is the default. Light or Dark applies only to this app and persists."),
        "记录想法": ("記錄想法", "Capture Thought"),
        "深入探讨": ("深入探討", "Explore"),
        "历史": ("歷史", "History"),
        "查看当前卡片的理解时间线": ("查看目前卡片的理解時間軸", "View this card's understanding timeline"),
        "查看答案": ("查看答案", "Reveal Answer"),
        "新建卡片": ("建立卡片", "New Card"),
        "批量导入": ("批次匯入", "Bulk Import"),
        "添加内容": ("新增內容", "Add Content"),
        "在 DeepSeek 网页继续讨论当前问题": ("在 DeepSeek 網頁繼續討論目前問題", "Continue exploring in DeepSeek"),
        "显示答案后才可以通过四向滑动进行复习评分": ("顯示答案後才能使用四向滑動進行複習評分", "Reveal the answer before rating with a swipe"),
        "正在准备复习…": ("正在準備複習…", "Preparing review…"),
        "刷新到期卡片": ("重新整理到期卡片", "Refresh Due Cards"),
        "正在载入到期卡片…": ("正在載入到期卡片…", "Loading due cards…"),
        "暂无到期卡片，可以稍后再来。": ("目前沒有到期卡片，稍後再來。", "No cards due. Check back later."),
        "本轮完成": ("本輪完成", "Session Complete"),
        "左·困难   上·良好   右·简单   下·再次": ("左·困難   上·良好   右·簡單   下·重來", "Left · Hard   Up · Good   Right · Easy   Down · Again"),
        "先回忆，再查看答案": ("先回憶，再查看答案", "Recall first, then reveal the answer"),
        "复习操作未完成": ("複習操作未完成", "Review Incomplete"),
        "无法读取 V3 复习数据": ("無法讀取 V3 複習資料", "Could Not Load Review Data"),
        "保存未成功，请重新滑动评分": ("儲存失敗，請重新滑動評分", "Could not save. Swipe again to rate."),
        "确定": ("確定", "OK"),
        "取消": ("取消", "Cancel"),
        "保存": ("儲存", "Save"),
        "编辑": ("編輯", "Edit"),
        "提交": ("提交", "Submit"),
        "关闭": ("關閉", "Close"),
        "记录理解": ("記錄理解", "Capture Understanding"),
        "记录此刻的想法": ("記錄此刻的想法", "Capture your thinking now"),
        "本次理解的文字记录": ("本次理解的文字記錄", "Understanding entry"),
        "记录未保存": ("記錄未儲存", "Entry Not Saved"),
        "理解时间线": ("理解時間軸", "Understanding Timeline"),
        "读取历史失败": ("讀取歷史失敗", "Could Not Load History"),
        "理解记录": ("理解記錄", "Understanding Entry"),
        "未评价": ("未評價", "Not Evaluated"),
        "含历史 AI 评价": ("含歷史 AI 評價", "Includes historical AI feedback"),
        "重来": ("重來", "Again"),
        "困难": ("困難", "Hard"),
        "良好": ("良好", "Good"),
        "容易": ("容易", "Easy"),
        "复习记录": ("複習記錄", "Review Event"),
        "真实评分事件": ("真實評分事件", "Recorded Rating"),
        "评分": ("評分", "Rating"),
        "原始题目": ("原始題目", "Original Question"),
        "我的理解": ("我的理解", "My Understanding"),
        "历史 AI 评价（只读）": ("歷史 AI 評價（唯讀）", "AI Feedback (Read Only)"),
        "之前的版本 · 不会被覆盖": ("先前版本 · 不會被覆蓋", "Previous Versions · Preserved"),
        "尚未评价": ("尚未評價", "No evaluation yet"),
        "修改理解会保存上一版本，不影响既有复习评分和历史评价。": ("修改理解會保存上一版本，不影響既有複習評分和歷史評價。", "Edits preserve the previous version and do not alter review ratings or prior AI feedback."),
        "历史版本": ("歷史版本", "Previous Version"),
        "编辑理解": ("編輯理解", "Edit Understanding"),
        "无法保存理解记录": ("無法儲存理解記錄", "Could Not Save Entry"),
        "还没有记录。\n回答、回顾和评价完成后会按时间展示在这里。": ("尚無記錄。\n回答、回顧與評價完成後會依時間顯示於此。", "No entries yet.\nYour answers, reviews and feedback will appear here."),
        "闪卡首页": ("閃卡首頁", "Flashcards Home"),
        "按文件夹浏览": ("依資料夾瀏覽", "Browse Folders"),
        "搜索相对路径": ("搜尋相對路徑", "Search paths"),
        "全部文档": ("全部文件", "All Documents"),
        "无标题": ("無標題", "Untitled"),
        "只读": ("唯讀", "Read Only"),
        "选择 Obsidian Vault（只读）": ("選擇 Obsidian Vault（唯讀）", "Choose Obsidian Vault (Read Only)"),
        "验证已授权 Vault（只读）": ("驗證已授權 Vault（唯讀）", "Verify Authorized Vault"),
        "断开 Vault 授权（不删除文件）": ("中斷 Vault 授權（不刪除檔案）", "Disconnect Vault (Keep Files)"),
        "Vault · 只读": ("Vault · 唯讀", "Vault · Read Only"),
        "断开 Obsidian Vault 授权？": ("中斷 Obsidian Vault 授權？", "Disconnect Obsidian Vault?"),
        "只清除 Impress 保存的访问书签，不会删除、修改或移动任何 Obsidian 文件，也不会删除本地笔记镜像。": ("僅清除 Impress 儲存的授權書籤，不會刪除、修改或移動 Obsidian 檔案。", "Removes only the saved access permission. No Obsidian files will be changed."),
        "断开": ("中斷連線", "Disconnect"),
        "连接 Obsidian Vault": ("連接 Obsidian Vault", "Connect Obsidian Vault"),
        "正在分批读取 Obsidian 文档…": ("正在分批讀取 Obsidian 文件…", "Loading Obsidian notes in batches…"),
        "此位置没有可读取的 Markdown 文档": ("此位置沒有可讀取的 Markdown 文件", "No readable Markdown documents here"),
        "连接 Obsidian Vault 后查看笔记": ("連接 Obsidian Vault 後查看筆記", "Connect an Obsidian Vault to see notes"),
        "Vault 索引预览 · 正在验证": ("Vault 索引預覽 · 正在驗證", "Vault index preview · Verifying"),
        "加载更多": ("載入更多", "Load More"),
        "无法读取源笔记": ("無法讀取來源筆記", "Could Not Open Note"),
        "Vault 只读验证完成": ("Vault 唯讀驗證完成", "Vault Verified"),
        "Vault 只读验证未通过": ("Vault 唯讀驗證失敗", "Vault Verification Failed"),
        "编辑独立草稿": ("編輯獨立草稿", "Edit Private Draft"),
        "切换 Markdown 源码": ("切換 Markdown 原始碼", "Toggle Markdown Source"),
        "编辑私有草稿": ("編輯私人草稿", "Edit Private Draft"),
        "只保存在 Impress · 不直接修改 Obsidian": ("僅儲存於 Impress · 不直接修改 Obsidian", "Saved only in Impress · Obsidian unchanged"),
        "源码": ("原始碼", "Source"),
        "草稿": ("草稿", "Draft"),
        "查看差异": ("查看差異", "View Changes"),
        "保存草稿": ("儲存草稿", "Save Draft"),
        "草稿已保存": ("草稿已儲存", "Draft Saved"),
        "无法打开独立草稿": ("無法開啟獨立草稿", "Could Not Open Draft"),
        "本地自动备份": ("本機自動備份", "Local Auto Backup"),
        "iCloud Drive 副本": ("iCloud Drive 副本", "iCloud Drive Copy"),
        "恢复": ("還原", "Restore"),
        "立即备份并导出": ("立即備份並匯出", "Back Up & Export"),
        "重新选择备份文件夹": ("重新選擇備份資料夾", "Choose Another Backup Folder"),
        "连接 iCloud Drive 文件夹": ("連接 iCloud Drive 資料夾", "Connect iCloud Drive Folder"),
        "断开自动云盘备份": ("停止自動雲端備份", "Disconnect Cloud Backup"),
        "从备份恢复": ("從備份還原", "Restore from Backup"),
        "恢复文件已安全暂存": ("還原檔案已安全暫存", "Restore Safely Staged"),
        "操作未完成": ("操作未完成", "Operation Incomplete"),
        "确认恢复 Impress 数据？": ("確認還原 Impress 資料？", "Restore Impress Data?"),
        "确认恢复": ("確認還原", "Confirm Restore"),
        "关闭提醒": ("關閉提醒", "Turn Off Reminders"),
        "智能到期提醒 · 每天 09:00 起": ("智慧到期提醒 · 每天 09:00 起", "Smart Due Reminders · From 09:00"),
        "每日习惯提醒 · 09:00": ("每日習慣提醒 · 09:00", "Daily Habit Reminder · 09:00"),
        "提醒通知": ("提醒通知", "Notifications"),
        "通知未授权": ("通知未授權", "Notifications Not Authorized"),
        "今日尚未完成五项评估": ("今日尚未完成五項評估", "Today's Five Assessments Incomplete"),
        "编辑目标": ("編輯目標", "Edit Goals"),
        "完成一次评估后，计算今日净得分。": ("完成一次評估後，計算今日淨得分。", "Complete assessments to calculate today's net score."),
        "早睡": ("早睡", "Early Sleep"),
        "运动": ("運動", "Exercise"),
        "饮食": ("飲食", "Nutrition"),
        "情绪": ("情緒", "Mood"),
        "自定义": ("自訂", "Custom"),
        "周": ("週", "Week"),
        "月": ("月", "Month"),
        "年": ("年", "Year"),
        "今日五项 · 点击进行评估": ("今日五項 · 點選進行評估", "Today's Five · Tap to Assess"),
        "额外行为修正（每种最多一次）": ("額外行為修正（每種最多一次）", "Additional Adjustments (One Each)"),
        "未完成提醒": ("未完成提醒", "Incomplete Assessment Reminders"),
        "待评估": ("待評估", "Not Assessed"),
        "载入中…": ("載入中…", "Loading…"),
        "没有记录": ("沒有記錄", "No Entries"),
        "额外加分 +1": ("額外加分 +1", "Extra Credit +1"),
        "额外减分 -1": ("額外扣分 -1", "Extra Deduction -1"),
        "未完成重复提醒": ("未完成重複提醒", "Repeat Reminders Until Complete"),
        "完成 · +1": ("完成 · +1", "Done · +1"),
        "未完成 · -1": ("未完成 · -1", "Not Done · -1"),
        "计划休息 / 不适用 · 0": ("計畫休息／不適用 · 0", "Rest / Not Applicable · 0"),
        "清除记录": ("清除記錄", "Clear Entry"),
        "清除评估": ("清除評估", "Clear Assessment"),
        "今日情绪 · 仅观察": ("今日情緒 · 僅觀察", "Today's Mood · Observation Only"),
        "今天跳过": ("今天跳過", "Skip Today"),
        "额外加分": ("額外加分", "Extra Credit"),
        "额外减分": ("額外扣分", "Extra Deduction"),
        "简短说明（最多120字）": ("簡短說明（最多120字）", "Brief reason (max 120 chars)"),
        "编辑四项行为标准": ("編輯四項行為標準", "Edit Four Behavior Goals"),
        "知道了": ("知道了", "Got It"),
        "校准数据未保存": ("校準資料未儲存", "Calibration Not Saved"),
        "生成选择题": ("產生選擇題", "Generate Quiz"),
        "生成问题和答案": ("產生問題和答案", "Generate Q&A"),
        "新增提示词": ("新增提示詞", "New Prompt"),
        "编辑提示词": ("編輯提示詞", "Edit Prompt"),
        "名称": ("名稱", "Name"),
        "内容": ("內容", "Content"),
        "复制": ("複製", "Copy"),
        "删除": ("刪除", "Delete"),
        "放弃": ("放棄", "Discard"),
        "继续编辑": ("繼續編輯", "Continue Editing"),
        "数据已保存": ("資料已儲存", "Saved"),
        "本次理解": ("本次理解", "My Answer"),
        "今日待评估 %d / 5 项": ("今日待評估 %d / 5 項", "Assessments Pending: %d / 5"),
        "今日净分 %@": ("今日淨分 %@", "Today's Net Score: %@"),
        "未评估不会自动扣分。情绪仅作观察，不参与加减分。": ("未評估不會自動扣分。情緒僅作觀察，不參與加減分。", "Unassessed items are not deductions. Mood does not affect the score."),
        "五项均已处理 · 本日提醒可停止 · 不代表个人价值": ("五項均已處理 · 今日提醒可停止 · 不代表個人價值", "All five assessed · Today's reminders can stop · Your score does not define you"),
        "今日已完成评估": ("今日已完成評估", "Today's Assessment Complete"),
        "今天没有可计分任务，休息与豁免不会产生扣分。": ("今天沒有可計分任務，休息與豁免不會產生扣分。", "No scored activities today. Rest and exemptions are not penalties."),
        "月均每日得分": ("月均每日得分", "Monthly Mean Daily Score"),
        "每日净分与7日均线": ("每日淨分與7日均線", "Daily Net Score & 7-Day Average"),
        "近30日净分与7日均线": ("近30日淨分與7日均線", "30-Day Net Score & 7-Day Average"),
        "完成 +1 · 未完成 -1 · 休息或豁免 0。情绪仅观察；明确跳过也算已评估。": ("完成 +1 · 未完成 -1 · 休息或豁免 0。情緒僅觀察；明確跳過也算已評估。", "Done +1 · Not done −1 · Rest 0. Mood is observation only; an explicit skip counts as assessed."),
        "仅记录未在四项任务中计过分的额外行为，避免重复扣分。": ("僅記錄未在四項任務中計過分的額外行為，避免重複扣分。", "Only adjust for actions not already scored in the four behavior goals."),
        "经系统授权后，在 20:00、22:00 提醒；完成当日五项后撤销剩余提醒。iOS 允许用户清除系统通知，无法创建永久置顶通知。": ("經系統授權後，在 20:00、22:00 提醒；完成當日五項後撤銷剩餘提醒。iOS 允許使用者清除系統通知，無法建立永久置頂通知。", "With permission, reminders are scheduled at 20:00 and 22:00. Completing all five cancels the remaining reminders. iOS notifications can be dismissed."),
        "已完成 · +1": ("已完成 · +1", "Completed · +1"),
        "休息 / 不适用 · 0": ("休息／不適用 · 0", "Rest / N/A · 0"),
        "尚未记录": ("尚未記錄", "Not Recorded"),
        "主动跳过（不计分）": ("主動跳過（不計分）", "Skipped (Not Scored)"),
        "未启用 · 点击申请 iOS 通知权限": ("未啟用 · 點選申請 iOS 通知權限", "Off · Tap to request iOS notification permission"),
        "已启用 · 每晚两次，完成即停止当天提醒": ("已啟用 · 每晚兩次，完成即停止當天提醒", "On · Twice nightly until today's assessments are complete"),
        "不以心情好坏评价自己，不参与每日得分。": ("不以心情好壞評價自己，不參與每日得分。", "Mood is observational and does not affect the daily score."),
        "清除": ("清除", "Clear"),
        "只记录计划之外的具体行为，不能重复计算今日任务。": ("只記錄計畫之外的具體行為，不能重複計算今日任務。", "Record only specific actions outside today's planned goals; do not count them twice."),
        "尚未完成的当日计划可调整；目标变化的项目会重新标为待评估。已完成的日期保留原目标。": ("尚未完成的當日計畫可調整；目標變動的項目會重新標為待評估。已完成日期保留原目標。", "You can edit unfinished goals. Modified items return to Not Assessed; completed days preserve their original goals."),
        "系统权限被关闭时，校准页面仍会保留未完成状态。可前往 iOS 设置启用通知。": ("系統權限關閉時，校準頁面仍會保留未完成狀態。可至 iOS 設定開啟通知。", "Incomplete assessments remain visible when notifications are disabled. You can enable them in iOS Settings."),
        "通知没有开启": ("通知未啟用", "Notifications Are Off"),
        "尚无成功备份": ("尚無成功備份", "No successful backup"),
        "尚未写入": ("尚未寫入", "Not yet copied"),
        "V3 数据变化后自动生成一致性快照。最近成功：%@。": ("V3 資料變動後自動產生一致性快照。最近成功：%@。", "Consistent snapshot after V3 changes. Last success: %@."),
        "不包含旧数据库、外部 Obsidian 原件、API Key 或 Vault 授权。": ("不包含舊資料庫、外部 Obsidian 原件、API Key 或 Vault 授權。", "Excludes legacy data, source Obsidian notes, API keys, and Vault permissions."),
        "当前 ZIP 未加密，获取文件者可读取其中学习数据。": ("目前 ZIP 未加密，取得檔案者可讀取其中的學習資料。", "The ZIP is not encrypted. Anyone with the file can read its learning data."),
        "首次手动授权文件夹，此后尝试静默复制。最近写入文件提供者：%@。": ("首次手動授權資料夾後會嘗試靜默複製。最近寫入檔案提供者：%@。", "After folder authorization, copying is automatic. Last Files-provider copy: %@."),
        "副本为未加密 ZIP，请只授权个人可信目录。系统 iCloud 上传可能延迟；": ("副本為未加密 ZIP，請僅授權個人可信任目錄。系統 iCloud 上傳可能延遲；", "Copies are unencrypted ZIP files. Use a private folder. iCloud upload may be delayed; "),
        "此状态不代表云端服务器已完成同步。": ("此狀態不代表雲端伺服器已完成同步。", "this status does not confirm server sync."),
        "恢复前验证归档，并创建当前数据的回滚备份。": ("還原前會驗證封存檔，並建立目前資料的回復備份。", "The archive is verified and a rollback copy is made before restore."),
        "确认后仅暂存，新数据在下次完全退出并重新启动 App 时载入。": ("確認後僅暫存，資料會在下次完全結束並重新啟動 App 時載入。", "Confirmation only stages the restore. Data loads at the next cold launch."),
        "同时生成本地备份；可保存到文件 App": ("同時產生本機備份；可儲存至「檔案」App", "Creates a local backup and exports through Files"),
        "仅在手动授权后自动写入副本": ("僅於手動授權後自動寫入副本", "Automatic copies require explicit folder permission"),
        "只清除本 App 的授权，不删除云盘文件": ("只清除此 App 的授權，不刪除雲端檔案", "Removes app access; keeps cloud files"),
        "先验证，再确认；不会直接覆盖当前数据库": ("先驗證、再確認；不會直接覆蓋目前資料庫", "Preview and confirm; no immediate database overwrite"),
        "确认备份隐私范围": ("確認備份隱私範圍", "Review Backup Privacy"),
        "Impress 备份 ZIP 当前没有密码加密，任何获得该文件的人都可能读取卡片、复习历史、理解记录与提示词。请选择仅自己可以访问的 iCloud Drive 文件夹。授权后将尝试静默复制，上传到 iCloud 服务器是否完成由系统决定。": ("Impress 備份 ZIP 目前沒有密碼加密。任何取得檔案的人都可能讀取卡片、複習歷史、理解記錄與提示詞。請選擇僅自己能存取的 iCloud Drive 資料夾。授權後會嘗試靜默複製，伺服器上傳由 iOS 控制。", "Impress backup ZIP files are not password encrypted. Anyone with the file can read cards, review history, understanding entries, and prompts. Choose a private iCloud Drive folder. Files copying does not guarantee iCloud server upload."),
        "继续选择文件夹": ("繼續選擇資料夾", "Choose Folder"),
        "请完全退出 Impress，再重新打开。恢复前的数据库备份已保留；不会触碰 Obsidian 源文件。": ("請完全結束 Impress，再重新開啟。還原前的資料庫備份已保留，不會修改 Obsidian 來源檔案。", "Fully close Impress and reopen it. The rollback database is preserved; source Obsidian notes are untouched."),
        "本机保存 · 可编辑、可复制": ("本機儲存 · 可編輯、可複製", "Stored Locally · Editable & Copyable"),
        "暂无提示词。点右上角 ＋ 创建。": ("尚無提示詞。點選右上角 ＋ 建立。", "No prompts yet. Tap + to create one."),
        "网页聊天不会自动收到提示词或私人笔记。在网页聊天中选择提示词后，会先复制到剪贴板，由你自行粘贴和发送。": ("網頁聊天不會自動收到提示詞或私人筆記。選取提示詞後只會複製到剪貼簿，由你自行貼上傳送。", "Prompts and private notes are never sent to web chat automatically. Copy and paste them manually."),
        "只会在本机保存。调用时复制内容，不会自动发送到网页。": ("只會儲存於本機。使用時複製內容，不會自動傳送至網頁。", "Saved only on this device. Copy to use; never auto-sent to websites."),
        "可复制的提示词正文": ("可複製的提示詞內文", "Prompt text (copyable)"),
        "提示词名称": ("提示詞名稱", "Prompt name"),
        "例如：费曼总结": ("例如：費曼總結", "E.g., Feynman Summary"),
        "无法保存": ("無法儲存", "Could Not Save"),
        "提示词未保存": ("提示詞未儲存", "Prompt Not Saved"),
        "放弃未保存的提示词？": ("放棄未儲存的提示詞？", "Discard Unsaved Prompt?"),
        "可以在 iOS 设置中允许 Impress 的通知。": ("可在 iOS 設定中允許 Impress 通知。", "Enable Impress notifications in iOS Settings."),
        "FSRS-6 决定到期时间；通知只负责提醒。智能提醒之间至少间隔 72 小时，关闭提醒不清除复习进度。": ("FSRS-6 決定到期時間，通知僅負責提醒。智慧提醒至少間隔 72 小時；關閉通知不會清除複習進度。", "FSRS-6 schedules reviews. Smart reminders are at least 72 hours apart. Turning them off does not erase progress."),
        "可在 iOS 系统设置中允许通知；当前模式不会被强制修改。": ("可在 iOS 系統設定中允許通知；目前模式不會被強制修改。", "Allow notifications in iOS Settings. Your selected reminder mode is unchanged."),
        "复习 · ": ("複習 · ", "Review · "),
        "题目\n": ("題目\n", "Question\n"),
        "\n\n本次理解\n": ("\n\n本次理解\n", "\n\nUnderstanding\n"),
        "\n\nAI 历史评价\n": ("\n\nAI 歷史評價\n", "\n\nHistorical AI Feedback\n"),
        "评分\n": ("評分\n", "Rating\n"),
        "\n\n发生时间\n": ("\n\n發生時間\n", "\n\nDate\n"),
        "\n\n下一次到期\n": ("\n\n下次到期\n", "\n\nNext Due\n"),
        "评估 · ": ("評估 · ", "Assess · "),
        "还没有校准记录": ("還沒有校準記錄", "No Calibration Data"),
        "条有效记录": ("筆有效記錄", " valid records"),
        "无 Markdown 样本。请确认所选目录。": ("無 Markdown 範例，請確認所選目錄。", "No Markdown notes were found. Check the selected folder."),
        "只会在 ImpressVault 不存在时首次复制。不会覆盖已有笔记，也不是双向同步。是否继续？": ("僅在 ImpressVault 不存在時首次複製，不會覆蓋既有筆記，也不是雙向同步。是否繼續？", "Copy only when ImpressVault does not already exist. Existing notes are never overwritten. This is not two-way sync. Continue?"),
        "笔记导入成功": ("筆記匯入成功", "Notes Imported"),
        " 篇（只读）": (" 篇（唯讀）", " notes (read only)"),
        "加载更多 · 已显示 ": ("載入更多 · 已顯示 ", "Load more · Showing "),
        "无内容": ("無內容", "No Content"),
        "旧版备份不含校准历史；保留本机现有校准数据。\n": ("舊版備份不含校準歷史；保留本機既有校準資料。\n", "Legacy backup has no calibration history; current calibration data is kept.\n"),
        "提示词模板：已验证\n": ("提示詞範本：已驗證\n", "Prompts: verified\n"),
        "Obsidian 外部原件不会被修改。\n\n": ("Obsidian 外部原件不會被修改。\n\n", "External Obsidian originals remain unchanged.\n\n"),
        "当前数据会先创建回滚备份，恢复在下次重新启动时生效。": ("目前資料會先建立回復備份，還原會在下次重新啟動時生效。", "A rollback copy is made before restoring on the next launch."),
        "名称和提示词不能为空，名称不超过 60 字、正文不超过 6000 字。": ("名稱與提示詞不得為空，名稱最多 60 字、內文最多 6000 字。", "Name and prompt are required. Maximum 60 and 6,000 characters."),
        "最多可保存 60 条提示词。": ("最多可儲存 60 筆提示詞。", "Up to 60 prompts may be saved."),
        "提示词 ID 或名称重复，请调整后重试。": ("提示詞 ID 或名稱重複，請修改後重試。", "Prompt ID or name already exists. Change it and retry."),
        "搜索问题、答案、来源": ("搜尋問題、答案、來源", "Search questions, answers, sources"),
        "没有找到匹配的卡片": ("找不到符合的卡片", "No Matching Cards"),
        "暂无卡片，点击右上角新建": ("尚無卡片，點選右上角新增", "No cards yet. Use + to create one."),
        "选择题": ("選擇題", "Multiple Choice"),
        "图片": ("圖片", "Image"),
        "问答": ("問答", "Q&A"),
        "已暂停": ("已暫停", "Paused"),
        "参与复习": ("參與複習", "Active"),
        "永久删除卡片？": ("永久刪除卡片？", "Delete Card Permanently?"),
        "这将同时删除该卡片的 FSRS 复习事件。外部 Obsidian 原始笔记不会被修改。": ("這也會刪除卡片的 FSRS 複習事件，外部 Obsidian 原始筆記不會修改。", "This also removes the card's FSRS events. Source Obsidian notes are untouched."),
        "暂停": ("暫停", "Pause"),
        "请填写卡片的问题。": ("請填寫卡片問題。", "Enter the card question."),
        "问答卡片需要一个答案。": ("問答卡片需要答案。", "Q&A cards require an answer."),
        "选择题需要 2 到 12 个选项。": ("選擇題需要 2 到 12 個選項。", "Multiple choice requires 2–12 options."),
        "请填写全部选项；单个选项不能包含换行。": ("請填寫全部選項；選項不得包含換行。", "Fill in each option on one line."),
        "选择题的选项不能重复。": ("選擇題的選項不可重複。", "Choice options must be unique."),
        "请直接点选至少一个正确答案。": ("請點選至少一個正確答案。", "Select at least one correct answer."),
        "单选模式只能标记一个正确答案；也可以切换到多选。": ("單選模式僅能標記一個正確答案，也可切換為多選。", "Single choice requires exactly one correct option; switch to multiple choice if needed."),
        "请选择并完成压缩一张图片。": ("請選擇並壓縮一張圖片。", "Choose and compress an image."),
        "单选": ("單選", "Single Choice"),
        "多选": ("多選", "Multiple Choice"),
        "新增卡片": ("新增卡片", "New Card"),
        "编辑卡片": ("編輯卡片", "Edit Card"),
        "卡片类型": ("卡片類型", "Card Type"),
        "问题": ("問題", "Question"),
        "答案": ("答案", "Answer"),
        "单选或多选": ("單選或多選", "Single or Multiple"),
        "选项（点选正确答案）": ("選項（點選正確答案）", "Options (Select Correct)"),
        "添加选项": ("新增選項", "Add Option"),
        "正确答案直接点击圆形标记；单选与多选均使用同一套 FSRS 复习评分。": ("直接點選圓形標記設定正確答案；單選、多選均使用 FSRS 複習評分。", "Tap the circular marker to set correct answers. Both modes use FSRS ratings."),
        "从照片选择图片": ("從相片選擇圖片", "Choose Photo"),
        "仅访问所选图片；取消不修改草稿，保存前在本机压缩。": ("僅存取所選圖片；取消不修改草稿，儲存前會在本機壓縮。", "Only the selected photo is accessed and compressed on device. Canceling preserves the draft."),
        "放弃未保存的内容？": ("放棄未儲存的內容？", "Discard Unsaved Changes?"),
        "取消不会写入 WCDB 或修改原始笔记。": ("取消不會寫入 WCDB 或修改原始筆記。", "Canceling does not modify WCDB or source notes."),
        "选中的项目不是受支持的图片。": ("所選項目不是支援的圖片格式。", "The selected item is not a supported image."),
        "正在本机压缩图片…": ("正在本機壓縮圖片…", "Compressing image on device…"),
        "图片读取失败或 iCloud 尚未下载。": ("圖片讀取失敗或 iCloud 尚未下載。", "Image could not be read or is not downloaded from iCloud."),
        "无法读取图片缩略图。": ("無法讀取圖片縮圖。", "Could Not Read Image Thumbnail."),
        "图片未修改，请重试。": ("圖片未修改，請重試。", "Image unchanged; please retry."),
        "上移": ("上移", "Move Up"),
        "下移": ("下移", "Move Down"),
        "文本": ("文字", "Text"),
        "预览": ("預覽", "Preview"),
        "选择输入格式，在本机解析。预览和逐题校验通过后才会写入闪卡数据库。": ("選擇輸入格式並在本機解析，預覽與逐題驗證後才會寫入閃卡資料庫。", "Choose a format and parse on device. Nothing is committed until preview and validation succeed."),
        "导入格式": ("匯入格式", "Import Format"),
        "MD 表示 Markdown；选择一种格式后，输入文本并预览。": ("MD 為 Markdown；選擇格式後輸入文字並預覽。", "MD means Markdown. Choose a format, enter text, and preview."),
        "选择文件": ("選擇檔案", "Choose File"),
        "Obsidian 笔记": ("Obsidian 筆記", "Obsidian Note"),
        "粘贴文本，或选择 CSV / TSV / Markdown 文件。": ("貼上文字，或選擇 CSV／TSV／Markdown 檔案。", "Paste text or select a CSV, TSV, or Markdown file."),
        "本地批量导入原始文本": ("本機批次匯入原始文字", "Local Bulk Import Text"),
        "文本/Markdown：Q: 问题、A: 答案。CSV/TSV：question、answer；选择题另提供 type=choice、options=A|B|C、correct=1,3（从 1 起）。无法识别的内容保留原文供修正。": ("文字／Markdown：Q: 問題、A: 答案。CSV／TSV 使用 question、answer；選擇題可新增 type=choice、options=A|B|C、correct=1,3。無法辨識的內容會保留原文。", "Text/Markdown: Q: question, A: answer. CSV/TSV: question, answer. Choices: type=choice, options=A|B|C, correct=1,3 (1-based). Unrecognized content is preserved."),
        "已修改输入文本，解除原 Obsidian 来源关联，避免来源错配。": ("已修改輸入文字，解除原 Obsidian 來源關聯，避免來源錯配。", "Edited input is unlinked from its original Obsidian source to prevent mismatches."),
        "无法读取文件": ("無法讀取檔案", "Could Not Read File"),
        "来源不一致": ("來源不一致", "Source Mismatch"),
        "授权笔记的身份发生变化。": ("授權筆記身分已變更。", "The authorized note identity has changed."),
        "文本过长": ("文字過長", "Text Too Long"),
        "导入文本不能超过 2MB。": ("匯入文字不得超過 2MB。", "Import text must not exceed 2 MB."),
        "无法读取笔记": ("無法讀取筆記", "Could Not Read Note"),
        "没有候选卡片": ("沒有候選卡片", "No Candidate Cards"),
        "先粘贴或选择包含问题和答案的文本。": ("請先貼上或選擇包含問題與答案的文字。", "Paste or choose text containing questions and answers."),
        "来源身份无效": ("來源身分無效", "Invalid Source Identity"),
        "放弃这次导入？": ("放棄本次匯入？", "Discard This Import?"),
        "未确认的候选不会写入数据库，也不会修改来源笔记。": ("未確認的候選不會寫入資料庫，也不會修改來源筆記。", "Unconfirmed candidates never modify the database or source notes."),
        "选择已授权笔记": ("選擇已授權筆記", "Choose Authorized Note"),
        "Vault 未授权或无法读取": ("Vault 未授權或無法讀取", "Vault Not Authorized or Unavailable"),
        "导入预览": ("匯入預覽", "Import Preview"),
        "全部导入": ("全部匯入", "Import All"),
        "与另一条候选问题重复。": ("與另一筆候選問題重複。", "Duplicate candidate question."),
        "点按编辑本题，详情按钮查看原文与原始错误，左滑移除。": ("點按編輯本題，詳情可查看原文與錯誤，左滑可移除。", "Tap to edit, inspect source text and errors, or swipe left to remove."),
        "原始导入文本及解析问题": ("原始匯入文字與解析問題", "Original Input & Parsing Issues"),
        "原始解析没有错误。": ("原始解析沒有錯誤。", "No original parsing errors."),
        "先确保所有候选正确。本次操作使用一次 WCDB 事务，源文件不会改变。": ("請先確認全部候選內容正確。本次操作使用單一 WCDB 交易，來源檔案不會變更。", "Verify all candidates first. This uses one WCDB transaction and never alters source files."),
        "返回预览": ("返回預覽", "Back to Preview"),
        "确认导入": ("確認匯入", "Confirm Import"),
        "预览校验失败": ("預覽驗證失敗", "Preview Validation Failed"),
        "完成": ("完成", "Done"),
        "导入未确认完成": ("匯入尚未確認完成", "Import Not Confirmed Complete"),
        "今日校准尚未完成": ("今日校準尚未完成", "Today's Calibration Is Incomplete"),
        "还有每日指标待评估。完成全部五项后，今天的后续提醒会停止。": ("仍有每日指標待評估。完成五項後，今日後續提醒將停止。", "Daily assessments remain. Completing all five stops the remaining reminders today."),
        "选项选择不计入复习评分": ("選項選擇不計入複習評分", "Selecting options does not rate the review"),
        "已选择": ("已選擇", "Selected"),
        "未选择": ("未選擇", "Not Selected"),
        "正确答案": ("正確答案", "Correct Answer"),
        "已选择，错误答案": ("已選擇，錯誤答案", "Selected, incorrect"),
        "搜索文件内容...": ("搜尋檔案內容...", "Search note content…"),
        "笔记内容为空，无法生成卡片。": ("筆記內容為空，無法產生卡片。", "Cannot create a card from an empty note."),
        "笔记卡片": ("筆記卡片", "Note Card"),
        "复习卡片创建成功！": ("複習卡片建立成功！", "Review card created."),
        "Obsidian 源文件目前为只读。请使用独立认知记录；双向写回必须经过版本比对和确认。": ("Obsidian 來源檔案目前唯讀。請使用獨立理解記錄；雙向寫回需經版本比對與確認。", "Obsidian source files are read-only. Use private drafts; source writes require version checks and approval."),
        "复制摘录": ("複製摘錄", "Copy Excerpt"),
        "复制所选文字": ("複製所選文字", "Copy Selection"),
        "确认后仅复制到系统剪贴板；不会保存到旧聊天记录或自动上传。": ("確認後僅複製到系統剪貼簿，不會儲存至舊聊天記錄或自動上傳。", "Copies only to the clipboard. No legacy chat storage or automatic upload."),
        "不安全的内部笔记链接": ("不安全的內部筆記連結", "Unsafe Internal Note Link"),
        "无法打开内部链接": ("無法開啟內部連結", "Could Not Open Internal Link"),
        "目标笔记不存在或索引需要刷新。": ("目標筆記不存在或索引需要更新。", "Note not found. The Vault index may need refreshing."),
        "存在同名笔记。请使用包含完整相对目录的 Obsidian 链接。": ("存在同名筆記，請使用完整相對路徑的 Obsidian 連結。", "Multiple notes share that name. Use the full relative path in the Obsidian link."),
        "目标笔记读取失败": ("目標筆記讀取失敗", "Could Not Read Linked Note"),
        "内部链接索引不可用": ("內部連結索引不可用", "Internal Link Index Unavailable"),
        "草稿超过安全大小限制": ("草稿超出安全大小限制", "Draft Exceeds Safe Size"),
        "草稿自动保存失败 · 请使用保存草稿": ("草稿自動儲存失敗 · 請手動儲存", "Auto-save failed · Use Save Draft"),
        "草稿保存失败 · 请检查可用存储空间": ("草稿儲存失敗 · 請檢查儲存空間", "Draft Save Failed · Check Storage"),
        "仅存储在 Impress 私有目录，没有修改 Obsidian 文件。": ("僅儲存於 Impress 私有目錄，沒有修改 Obsidian 檔案。", "Saved in private Impress storage. Obsidian originals were not modified."),
        "保存草稿失败": ("儲存草稿失敗", "Could Not Save Draft"),
        "无法持久化草稿": ("無法持久化草稿", "Could Not Persist Draft"),
        "源文件已被其他应用修改": ("來源檔案已遭其他 App 修改", "Source Was Modified Elsewhere"),
        "无法检查 Obsidian 当前版本": ("無法驗證 Obsidian 目前版本", "Could Not Verify Current Obsidian Version"),
        "源文件差异": ("來源檔案差異", "Source Differences"),
        "确认写回": ("確認寫回", "Confirm Source Write"),
        "确认修改 Obsidian 源文件？": ("確認修改 Obsidian 來源檔案？", "Modify Obsidian Source?"),
        "将重新验证源文件 SHA-256，并先保存私有恢复副本。如果出现版本冲突会拒绝覆盖。": ("將重新驗證來源 SHA-256 並先儲存私人復原副本；遇到版本衝突時會拒絕覆蓋。", "Reverify the source SHA-256 and save a private recovery copy. Version conflicts prevent overwrites."),
        "写入已验证并保留恢复副本。": ("寫入已驗證並保留復原副本。", "Write verified and recovery copy preserved."),
        "Vault 写回结果": ("Vault 寫回結果", "Vault Write Result"),
        "语音输入": ("語音輸入", "Voice Input"),
        "语音与听写": ("語音與聽寫", "Voice & Dictation"),
        "识别语言、Apple 端侧模型与录音权限": ("辨識語言、Apple 裝置端模型與錄音權限", "Language, Apple on-device models and microphone access"),
        "仅使用 Apple 端侧语音模型，录音不会写入历史或发送到服务器。": ("僅使用 Apple 裝置端語音模型；錄音不寫入歷史，也不傳送至伺服器。", "Uses Apple on-device speech models only; no recording history or server uploads."),
        "普通话（简体）": ("普通話（簡體）", "Mandarin (Simplified)"),
        "中文（繁体）": ("中文（繁體）", "Chinese (Traditional)"),
        "另一个语音输入会话仍在进行。": ("另一個語音輸入工作階段仍在進行。", "Another voice-input session is in progress."),
        "麦克风未授权，可在 iOS 设置中启用。": ("麥克風未授權，可在 iOS 設定中開啟。", "Microphone access is denied. Enable it in iOS Settings."),
        "此设备或识别语言没有可用的 Apple 端侧语音模型。": ("此裝置或語言沒有可用的 Apple 裝置端語音模型。", "No Apple on-device speech model is available for this device or language."),
        "该语言需要先下载 Apple 端侧识别模型。": ("必須先下載此語言的 Apple 裝置端辨識模型。", "Download the Apple on-device model for this language first."),
        "无法访问麦克风，请在真机检查录音设备。": ("無法存取麥克風，請在實機檢查錄音裝置。", "Microphone is unavailable. Check recording access on your device."),
        "没有获得可插入的最终识别文本。": ("沒有可插入的最終辨識文字。", "No finalized transcript is available to insert."),
        "本次语音输入已取消。": ("本次語音輸入已取消。", "Voice input was canceled."),
        "语音输入被系统中断。原有文字没有改变。": ("語音輸入遭系統中斷。原本文字沒有改變。", "Recording was interrupted; existing text remains unchanged."),
        "识别中断，请结束或取消": ("辨識中斷，請結束或取消", "Recognition interrupted. Finish or cancel."),
        "原输入框已关闭，本次识别不会修改任何内容。": ("原輸入框已關閉，辨識結果不會修改內容。", "The original editor has closed; no text was changed."),
        "录音期间文本已发生变化；为避免覆盖，请重新开始。": ("錄音期間文字已有變動；為避免覆蓋，請重新開始。", "The editor changed during recording. Restart to avoid overwriting."),
        "原光标位置已失效；本次识别没有插入。": ("原游標位置已失效；未插入辨識文字。", "The original caret selection is no longer valid. Nothing was inserted."),
        "当前编辑器拒绝这次文本插入。": ("目前編輯器拒絕插入文字。", "The editor rejected the dictation text."),
        "开始语音输入": ("開始語音輸入", "Start Voice Input"),
        "准备语音输入": ("準備語音輸入", "Preparing Voice Input"),
        "识别文本将在此预览，结束后才插入原编辑框。": ("辨識文字先在此預覽，結束後才會插入原編輯框。", "The transcript is previewed here and inserted only when finished."),
        "开始录音": ("開始錄音", "Start Recording"),
        "识别模型未安装": ("尚未安裝辨識模型", "Speech Model Not Installed"),
        "正在安装 Apple 端侧模型…": ("正在安裝 Apple 裝置端模型…", "Installing Apple on-device model…"),
        "正在启动录音…": ("正在啟動錄音…", "Starting recording…"),
        "正在聆听": ("正在聆聽", "Listening…"),
        "结束并插入": ("結束並插入", "Finish & Insert"),
        "无法开始录音": ("無法開始錄音", "Could Not Start Recording"),
        "下载 Apple 识别模型？": ("下載 Apple 辨識模型？", "Download Apple Speech Model?"),
        "仅首次需要联网下载；录音和转文字在设备端处理。": ("僅初次需要連線下載；錄音與轉文字於裝置端處理。", "First-use download requires internet. Recording and transcription stay on device."),
        "下载并继续": ("下載並繼續", "Download & Continue"),
        "正在完成识别…": ("正在完成辨識…", "Finalizing transcript…"),
        "重新录音": ("重新錄音", "Record Again"),
        "语音输入未完成": ("語音輸入未完成", "Voice Input Incomplete"),
        "无法完成语音输入": ("無法完成語音輸入", "Could Not Complete Voice Input"),
        "识别语言": ("辨識語言", "Recognition Language"),
        "Apple 端侧模型": ("Apple 裝置端模型", "Apple On-Device Model"),
        "权限与隐私": ("權限與隱私", "Permissions & Privacy"),
        "听写语言与 App 的显示语言互不影响。": ("聽寫語言與 App 顯示語言互不影響。", "Dictation language is independent of the app interface language."),
        "Apple 按设备和语言提供模型；首次下载需联网，识别过程不上传音频。": ("Apple 依裝置與語言提供模型；初次下載需要網路，辨識不會上傳音訊。", "Apple models depend on device and language. Initial download needs internet; audio stays local."),
        "仅在点击麦克风后录音，不保存音频；取消时不修改编辑器文本。": ("只在點選麥克風後錄音，不保存音訊；取消不會修改編輯文字。", "Recording starts only after tapping the mic. No audio is saved, and cancel preserves text."),
        "识别引擎": ("辨識引擎", "Recognition Engine"),
        "检查中…": ("檢查中…", "Checking…"),
        "当前设备不支持": ("目前裝置不支援", "Not Supported on This Device"),
        "识别模型": ("辨識模型", "Speech Model"),
        "正在下载模型…": ("正在下載模型…", "Downloading Model…"),
        "已安装，可离线识别": ("已安裝，可離線辨識", "Installed · Offline Ready"),
        "不可用": ("不可用", "Unavailable"),
        "未安装 · 点击下载": ("未安裝 · 點選下載", "Not Installed · Tap to Download"),
        "麦克风权限": ("麥克風權限", "Microphone Access"),
        "已授权": ("已授權", "Authorized"),
        "未授权 · 点击打开系统设置": ("未授權 · 點選開啟系統設定", "Denied · Open iOS Settings"),
        "首次开始录音时请求授权": ("首次開始錄音時請求授權", "Requested When Recording Starts"),
        "音频隐私": ("音訊隱私", "Audio Privacy"),
        "录音只在设备端识别，取消后不会保存音频或文字。": ("錄音只在裝置端辨識；取消不會保存音訊或文字。", "On-device recognition only. Cancel saves neither audio nor transcript."),
        "下载": ("下載", "Download"),
        "AI 服务": ("AI 服務", "AI Services"),
        "API 连接": ("API 連線", "API Connections"),
        "添加 API 连接": ("新增 API 連線", "Add API Connection"),
        "连接名称": ("連線名稱", "Connection Name"),
        "服务商 / 协议": ("服務商／協定", "Provider / Protocol"),
        "协议类型": ("協定類型", "API Protocol"),
        "选择服务商": ("選擇服務商", "Choose Provider"),
        "模型列表": ("模型清單", "Available Models"),
        "个模型": (" 個模型", " models"),
        "业务默认模型": ("業務預設模型", "Default Models by Task"),
        "指定笔记出题": ("指定筆記出題", "Generate Questions from Note"),
        "知识重构（尚未启用）": ("知識重構（尚未啟用）", "Knowledge Synthesis (Not Enabled)"),
        "原生对话（尚未启用）": ("原生對話（尚未啟用）", "Native Chat (Not Enabled)"),
        "隐私与数据边界": ("隱私與資料邊界", "Privacy & Data Scope"),
        "数据上传规则": ("資料上傳規則", "Data Sharing Rules"),
        "按需授权、仅上传选定文档、不会修改原始 Vault": ("按需授權，僅上傳選定文件，不會修改原始 Vault", "Explicit access; selected notes only; no Vault edits"),
        "仅在你明确确认生成时发送选定的笔记内容；API Key 留在本机 Keychain。": ("僅在你明確確認產生題目時傳送所選筆記；API Key 留在裝置的 Keychain。", "Selected notes are sent only after confirmation. API keys remain in device Keychain."),
        "每个连接独立保存 API Key，可添加多个服务商和模型。": ("每個連線分別保存 API Key，可新增多個服務商與模型。", "Each connection has its own API key. Add multiple providers and models."),
        "指定笔记出题需要先测试模型 JSON 能力。不会自动跨服务商发送笔记。": ("指定筆記出題需先測試模型 JSON 能力；不會自動跨服務商傳送筆記。", "Test JSON support before generating questions. Notes never switch providers automatically."),
        "云端模型会接收你明确选择的笔记片段。服务商可能根据各自政策处理请求；不会默认上传整个 Obsidian Vault。所有自动写回仍被生产安全门禁关闭。": ("雲端模型會接收你明確選擇的筆記片段。服務商可能依其政策處理資料；不會預設上傳整個 Vault。自動寫回仍受安全限制。", "Cloud models receive only selected note excerpts. Providers apply their own data policies. The full Vault is never uploaded by default and automated writes remain disabled."),
        "未配置": ("尚未設定", "Not Configured"),
        "未保存": ("尚未儲存", "Not Saved"),
        "已保存": ("已儲存", "Saved"),
        "未测试": ("尚未測試", "Not Tested"),
        "JSON 已验证": ("JSON 已驗證", "JSON Verified"),
        "JSON 测试已通过": ("JSON 測試已通過", "JSON Test Passed"),
        "尚未验证 JSON 输出": ("尚未驗證 JSON 輸出", "JSON Output Not Verified"),
        "测试 JSON 输出": ("測試 JSON 輸出", "Test JSON Output"),
        "作为出题模型": ("設為出題模型", "Use for Question Generation"),
        "作为对话模型": ("設為對話模型", "Use for Chat"),
        "已选择默认模型": ("已選擇預設模型", "Default Model Selected"),
        "选择业务模型": ("選擇業務模型", "Choose Task Model"),
        "删除模型": ("刪除模型", "Delete Model"),
        "添加模型 ID": ("新增模型 ID", "Add Model ID"),
        "删除连接": ("刪除連線", "Delete Connection"),
        "删除 API 连接？": ("刪除 API 連線？", "Delete API Connection?"),
        "连接、其模型和业务路由将被移除；Keychain 密钥也会删除。": ("連線、模型與業務路由將被移除；Keychain 密鑰也會刪除。", "This removes the connection, its models and routes, and its Keychain credential."),
        "操作失败": ("操作失敗", "Operation Failed"),
        "添加": ("新增", "Add"),
        "选择失败": ("選擇失敗", "Selection Failed"),
        "该功能尚未开放": ("此功能尚未開放", "Not Available Yet"),
        "知识重构需要单独的工具调用及 Vault 写回安全验收。": ("知識重構需先通過工具呼叫與 Vault 寫回安全驗收。", "Knowledge synthesis requires separate tool and Vault write-safety verification."),
        "模型响应不符合格式要求，未生成卡片。": ("模型回應格式不符，未產生卡片。", "The model response is invalid. No cards were generated."),
        "服务商未返回模型列表，请手动输入模型 ID。": ("服務商未回傳模型清單，請手動輸入模型 ID。", "No model list was returned. Enter a model ID manually."),
        "请求或响应超出安全长度限制。": ("請求或回應超出安全長度限制。", "The request or response exceeds the size limit."),
        "API Key 不可用，请重新保存密钥。": ("API Key 不可用，請重新儲存密鑰。", "API key unavailable. Save it again."),
        "API 地址不安全或不正确。": ("API 位址不安全或不正確。", "API endpoint is unsafe or invalid."),
        "API 授权失败，请检查密钥。": ("API 授權失敗，請檢查密鑰。", "API authorization failed. Check your key."),
        "请先在设置中配置并测试 AI 出题模型。": ("請先在設定中配置並測試 AI 出題模型。", "Configure and test a question-generation model in Settings first."),
        "快速记录": ("快速記錄", "Quick Capture"),
        "补充理解": ("補充理解", "Add Understanding"),
        "查看理解与复习历史": ("查看理解與複習紀錄", "View Understanding & Review History"),
        "卡片管理": ("卡片管理", "Manage Cards"),
        "根据笔记生成综合问题": ("根據筆記產生綜合問題", "Generate Comprehensive Questions"),
        "生成综合问题": ("產生綜合問題", "Generate Questions"),
        "出题数量": ("出題數量", "Number of Questions"),
        "道综合题": (" 道綜合題", " comprehensive questions"),
        "生成": ("產生", "Generate"),
        "生成中…": ("產生中…", "Generating…"),
        "选择要分析的笔记章节": ("選擇要分析的筆記章節", "Choose Note Sections"),
        "字符": ("字元", "characters"),
        "未命名章节": ("未命名章節", "Untitled Section"),
        "默认5道综合理解与应用题，不要求AI为凑数量编造内容。": ("預設五道理解與應用綜合題，不要求 AI 為湊數而捏造內容。", "Default: 5 comprehensive questions. The AI must not fabricate extra questions."),
        "只上传勾选章节及其文本，原始 Obsidian 文件保持只读。": ("僅上傳勾選的章節文字，Obsidian 原始檔案維持唯讀。", "Only selected section text is sent. Source Obsidian notes remain read-only."),
        "只发送已勾选章节给该云端 API 服务商，不会上传整个 Vault；原文不会被修改。": ("僅將勾選章節送至所選 API 服務商；不會上傳整個 Vault，亦不修改原文。", "Only checked sections go to this provider. The full Vault is not uploaded and originals are untouched."),
        "确认发送所选笔记？": ("確認傳送所選筆記？", "Send Selected Note Sections?"),
        "无法生成问题": ("無法產生問題", "Could Not Generate Questions"),
        "问题候选池": ("問題候選池", "Question Candidates"),
        "道候选 · 点选勾选，点信息按钮编辑": (" 道候選 · 點選勾選，資訊鍵編輯", " candidates · Tap to select, info to edit"),
        "参考答案": ("參考答案", "Reference Answer"),
        "编辑候选题": ("編輯候選題", "Edit Candidate"),
        "加入": ("加入", "Add"),
        "张": (" 張", " cards"),
        "加入卡片集": ("加入卡片集", "Add to Card Collection"),
        "加入卡片集？": ("加入卡片集？", "Add to Card Collection?"),
        "确认加入": ("確認加入", "Confirm Add"),
        "卡片已添加": ("卡片已新增", "Cards Added"),
        "张卡片已保存到 V3 卡片集。": (" 張卡片已儲存至 V3 卡片集。", " cards have been saved to the V3 card collection."),
        "张问答卡片将进入 FSRS 复习。Obsidian 原文不会修改。": (" 張問答卡片將加入 FSRS 複習；Obsidian 原文不會修改。", " Q&A cards will enter FSRS review. Source Obsidian notes remain unchanged."),
        "无法保存卡片": ("無法儲存卡片", "Could Not Save Cards"),
        "来源依据（只读）": ("來源依據（唯讀）", "Source Evidence (Read Only)"),
        "来源引用仅供核对，不能单独证明答案正确。加入前请确认内容。": ("來源引用僅供查核，不能單獨證明答案正確。加入前請確認內容。", "Citations aid verification but do not guarantee correctness. Review answers before adding."),
        "自定义 API": ("自訂 API", "Custom API"),
        "认证方式": ("驗證方式", "Authentication"),
        "自定义 Header 名称": ("自訂 Header 名稱", "Custom Header Name"),
        "API 接口路径": ("API 介面路徑", "API Endpoint Paths"),
        "模型协议": ("模型協定", "Model Protocol"),
        "JSON 输出模式": ("JSON 輸出模式", "JSON Output Mode"),
        "沿用连接协议": ("沿用連線協定", "Use Connection Protocol"),
        "真机 QA 仅支持独立的测试 Vault 副本": ("真機 QA 僅支援獨立的測試 Vault 副本", "Device QA is limited to a separate test Vault copy"),
        "测试副本写回": ("測試副本寫回", "Write Test Copy"),
        "仅限测试副本；原始 Vault 仍保持只读": ("僅限測試副本；原始 Vault 仍維持唯讀", "Test copy only; original Vault remains read-only"),
        "请在「文件」App 选择 Impress-Write-Test-Vault 测试副本": ("請在「檔案」App 選取 Impress-Write-Test-Vault 測試副本", "Choose the Impress-Write-Test-Vault copy in Files"),
        "确认修改独立测试副本？": ("確認修改獨立測試副本？", "Modify the Separate Test Copy?"),
        "仅操作「文件」中名称为 Impress-Write-Test-Vault 的独立副本。正式 Vault 不可写入。将重新核对原文 SHA-256，保存恢复副本后再尝试写入；请先自行复制重要笔记。": ("僅操作「檔案」中名稱為 Impress-Write-Test-Vault 的獨立副本。正式 Vault 不可寫入。將重新驗證原始 SHA-256，建立復原副本後再嘗試寫入；請先另外備份重要筆記。", "Only the independent folder named Impress-Write-Test-Vault in Files can be modified. The real Vault remains read-only. The original SHA-256 is rechecked and a recovery copy saved before writing. Back up important notes first."),
        "确认测试副本写回": ("確認測試副本寫回", "Confirm Test Copy Write"),
        "模型下载失败": ("模型下載失敗", "Model Download Failed")
    ]

    /// Call only for product-owned literals, never for user-created content.
    static func text(_ simplified: String,
                     language: ImpressV3Language? = nil) -> String {
        let target = language ?? selected()
        guard let entry = translations[simplified] else { return simplified }
        switch target {
        case .simplified: return simplified
        case .traditional: return entry.traditional
        case .english: return entry.english
        }
    }
}

@inline(__always)
func V3L(_ simplified: String) -> String {
    ImpressV3Language.text(simplified)
}
