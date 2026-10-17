import Foundation
import WCDBSwift

// 定义大模型提供商枚举
enum LLMProvider: String, Codable {
    case gpt = "GPT"
    case gemini = "Gemini"
    case openRouter = "OpenRouter"
    case custom = "自定义"
}

// 定义大模型配置的数据模型
struct ImLLMModel: TableCodable {
    // MARK: - Properties
    
    /// 唯一标识符，主键
    var identifier: Int?
    /// 用户给模型取的名字
    var name: String?
    /// 模型提供商
    var provider: String?
    /// API Key
    var apiKey: String?
    /// 模型的具体标识，例如 "gpt-4-1106-preview"
    var modelIdentifier: String?
    /// 模型的温度参数，控制生成文本的创造性
    var temperature: Double?
    /// 自定义提供商的 Base URL
    var customBaseURL: String?
    /// 是否为默认选中的模型
    var isDefault: Bool?
    /// 创建时间
    var creationDate: Date?
    
    var providerType: LLMProvider? {
        guard let provider = provider else { return nil }
        return LLMProvider(rawValue: provider)
    }
    
    /// 根据提供商类型计算 Base URL
    var baseURL: String? {
        switch providerType {
        case .gpt:
            return "https://api.openai.com/v1/chat/completions"
        case .gemini:
            // 注意：Gemini 的 URL 格式可能需要根据具体 API 版本调整
            return "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
        case .openRouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        case .custom:
            guard let customBaseURL = customBaseURL else { return nil }
            // 对于兼容OpenAI的API，如果没有chat/completions，自动添加
            if customBaseURL.hasSuffix("/v1") && !customBaseURL.hasSuffix("/v1/chat/completions") {
                return customBaseURL + "/chat/completions"
            }
            return customBaseURL
        case .none:
            return nil
        }
    }
    
    // MARK: - WCDB Table Coding
    enum CodingKeys: String, CodingTableKey {
        typealias Root = ImLLMModel
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case identifier = "id"
        case name
        case provider
        case apiKey
        case modelIdentifier
        case temperature
        case customBaseURL = "baseURL"
        case isDefault
        case creationDate
        
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .identifier: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true),
                .isDefault: ColumnConstraintBinding(defaultTo: false),
                .temperature: ColumnConstraintBinding(defaultTo: 0.7),
                .creationDate: ColumnConstraintBinding(defaultTo: Date())
            ]
        }
    }
}
