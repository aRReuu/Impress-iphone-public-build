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
    // Native grouped canvas under all primary screens and the floating TabBar.
    // The slightly elevated surface belongs to content, input and grouped rows.
    static let page = UIColor.systemGroupedBackground
    static let surface = UIColor.secondarySystemGroupedBackground
    // Segments keep a visible track without faux glass or custom shadow art.
    static let segmentTrack = UIColor.tertiarySystemFill
    static let secondarySegmentSelection = UIColor.tertiarySystemGroupedBackground
    static let mutedAction = UIColor.systemGray
    static let quietControlSurface = UIColor.secondarySystemFill
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
