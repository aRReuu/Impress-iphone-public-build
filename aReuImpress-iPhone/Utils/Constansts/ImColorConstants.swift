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
