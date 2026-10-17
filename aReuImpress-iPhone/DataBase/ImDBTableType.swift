//
//  DBTableType.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 3/21/25.
//


/// 表格类型
/// update 20241201删减90%表
enum ImDBTableType:String, CustomStringConvertible
{
    ///笔记复盘页
    case notes
    /// 卡片数据集
    case card
    /// 轮询对话
    case pollingChat
    /// LLM 模型
    case llmModel
    /// 标记问题
    case preChat
    
    var description:String {
        switch self {
            case .notes: return "impress_notes"
            case .card: return "impress_card"
            case .preChat: return "impress_chat"
            case .pollingChat: return "impress_polling_chat"
            case .llmModel: return "impress_llm_model"
        }
    }
}
