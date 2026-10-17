//
//  ImPreChatModel.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 7/28/25.
//  该模型为单个笔记对应(映射)的某条问题, 对应Home页面的数据模型

import WCDBSwift

public struct ImPreChatModel: TableCodable, ImSubmitConfigureProtocol
{
    /// primaryKey
    var identifier: Int?
    
    /// 关联NoteListModel ID
    var noteID: Int?
    
    /// 更新时间
    var updateTime:Date?
    
    /// 讨论标题
    var question: String?
    
    /// 内容
    var content: String?
    
    // 在对话结束生成总结时赋值
    /// web对话详细链接
    var url: String?
    
    /// 是否进行对话
    var isChated : Bool?
    
    /// 标题出处
    var questionSource: String?

    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = ImPreChatModel
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case identifier = "id"
        case noteID = "note_id"
        case question
        case content
        case updateTime = "update_time"
        case url
        case isChated = "is_chated"
        case questionSource = "question_source"
        
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .identifier: ColumnConstraintBinding(isPrimary: true,isAutoIncrement: true),
                .isChated: ColumnConstraintBinding(defaultTo: false)    //默认为尚未对话状态
            ]
        }
    }
    
    // MARK: - ImSubmitConfigureProtocol协议实现
    var submitQuestion: String?
    {
        get{self.question}
        set{self.question = newValue}
    }
    
    var submitAnswer: String?
    {
        get{self.content}
        set{self.content = newValue}
    }
    
    var submitNoteID: Int?
    {
        get{self.noteID}
        set{self.noteID = newValue}
    }

    var submitType: ImSubmitType
    {
        get {ImSubmitType.chat}
    }
}

