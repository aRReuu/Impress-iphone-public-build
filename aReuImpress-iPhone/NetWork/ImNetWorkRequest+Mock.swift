//
//  ImNetWorkRequest+Mock.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 10/11/25.
//


extension ImNetWorkRequest
{
    /// 生成完整的 Markdown 语法示例
    /// - Returns: 包含丰富 Markdown 格式的演示字符串
    private func generateEnhancedMockMarkdown() -> String {
        let mockContents = [
            """
            # 高级 Swift 语法示例

            ## 协议与扩展
            协议定义了方法的蓝图，扩展则提供了默认实现：

            ### Protocol 定义
            ```swift
            protocol Vehicle {
                var speed: Double { get }
                func accelerate(by amount: Double)
            }

            extension Vehicle {
                func stop() {
                    // 默认实现
                }
            }
            ```

            #### 结构体实现
            ```swift
            struct Car: Vehicle {
                var speed: Double = 0.0
                mutating func accelerate(by amount: Double) {
                    speed += amount
                }
            }
            ```

            - **关联类型**：用于泛型协议
            - **where 子句**：约束协议扩展
            - **@objc 标记**：Objective-C 兼容性

            > 提示：协议组合允许一个类型符合多个协议，提高代码复用性。

            1. 定义协议接口
            2. 实现协议方法
            3. 使用扩展添加功能

            学习资源：[Swift 协议文档](https://developer.apple.com/documentation/swift/protocol)
            """,
            """
            # iOS 内存管理实践

            ## ARC 与引用周期

            ### 强引用循环
            ```swift
            class Person {
                var pet: Dog?
            }

            class Dog {
                weak var owner: Person?
            }
            ```

            #### 解决方法
            - 使用 `weak` 引用打破循环
            - 使用 `unowned` 处理确定性生命周期
            - 必要时手动管理内存

            - 自动引用计数
            - 弱引用与无主引用
            - 内存泄漏检测

            > 注意：在闭包中使用 `[weak self]` 或 `[unowned self]` 避免循环引用。

            ### 最佳实践
            1. 理解对象生命周期
            2. 使用合适的引用类型
            3. 监控内存使用情况

            [内存管理指南](https://developer.apple.com/documentation/swift/automatic_reference_counting)
            """,
            """
            # Combine 响应式编程

            ## 发布者与订阅者

            ### 基本操作符
            ```swift
            let publisher = Just("Hello")
                .map { $0 + ", World!" }
                .sink { print($0) }
            ```

            #### 错误处理
            ```swift
            let errorPublisher = Fail<String, Error>(error: URLError(.badURL))
                .catch { _ in Just("Default Value") }
            ```

            - **Just**: 发出单个值
            - **Map**: 转换值
            - **Filter**: 过滤值
            - **Sink**: 订阅接收者

            > 提示：使用 `assign(to:)` 或 `store(in:)` 管理订阅生命周期。

            ### 实际应用场景
            1. 网络请求响应
            2. 用户界面状态绑定
            3. 数据流处理

            深入了解：[Combine 框架](https://developer.apple.com/documentation/combine)
            """
        ]

        return mockContents.randomElement() ?? ""
    }

    /// 获取模拟数据响应
    /// - Returns: 模拟的网络响应结果，包含模拟内容和使用情况
    func getMockDataResponse() -> (content: String, usage: Usage?) {
        let mockContent = generateEnhancedMockMarkdown()
        let mockUsage = Usage(
            promptTokens: Int.random(in: 40...80),
            completionTokens: Int.random(in: 120...300),
            totalTokens: Int.random(in: 160...380),
            completionTokensDetails: nil,
            promptTokensDetails: nil
        )
        return (content: mockContent, usage: mockUsage)
    }
}

