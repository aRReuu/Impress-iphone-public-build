
import Foundation
import WCDBSwift

// 定义消息发送方
enum MessageSender: Int, Codable {
    case user = 0
    case bot = 1
}

// 定义消息发送状态
enum MessageStatus: Int, Codable {
    case sending
    case sent
    case failed
}

// 定义下划线范围信息
struct UnderlineRange: Codable, Hashable {
    let id: UUID                    // 下划线唯一标识
    let startIndex: Int            // 下划线起始位置
    let length: Int                // 下划线长度
    let timestamp: Date            // 下划线创建时间
    let text: String               // 下划线文本内容
}

// 定义聊天消息的数据模型
struct ImPollingChatMessage: Codable, Hashable {
    let id: UUID
    var content: String
    let sender: MessageSender
    let timestamp: Date
    var status: MessageStatus? = .sent
    var underlines: [UnderlineRange]? = nil // 下划线信息，支持版本兼容
}

// 完整的对话会话模型，用于数据库存储
struct ImPollingChatModel: TableCodable {
    // 主键
    var identifier: Int?
    // 更新时间
    var updateTime: Date?
    // 对话标题
    var title: String?
    // 副标题/描述
    var subTitle: String?
    // 所有的聊天记录
    var messages: [ImPollingChatMessage]?
    // 摘录的内容数组
    var extractedTexts: [String]?

    enum CodingKeys: String, CodingTableKey {
        public typealias Root = ImPollingChatModel
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)

        case identifier = "id"
        case updateTime = "update_time"
        case title
        case subTitle
        case messages
        case extractedTexts

        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .identifier: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
    }
}

// MARK: - ImSubmitConfigureProtocol
extension ImPollingChatModel: ImSubmitConfigureProtocol {
    var submitQuestion: String? {
        get { return title }
        set { title = newValue }
    }

    var submitAnswer: String? {
        get {
            // Combine all message contents into a single string
            return messages?.map { $0.content }.joined(separator: "\n\n")
        }
        set {
            // When editing, we need to handle this special case
            // We'll store the new content in subTitle for now, and handle reconstruction in the edit completion
            subTitle = newValue
        }
    }

    var submitNoteID: Int? {
        get { return identifier }
        set { identifier = newValue }
    }

    var submitType: ImSubmitType {
        return .chat
    }

    var submitExtractedTexts: [String]? {
        get { return extractedTexts }
        set { extractedTexts = newValue }
    }
}
