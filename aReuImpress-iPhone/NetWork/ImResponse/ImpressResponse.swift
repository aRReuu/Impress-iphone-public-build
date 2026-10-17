//
//  ImpressResponse.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 11/21/24.
//


/// LLM 网络返回报文请求结构体
struct ImpressResponse: Codable
{
    let id: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?

    //智谱清言
    let requestID:String?

    // subOpenAI
    let object: String?
    let systemFingerprint: String?

    enum CodingKeys: String, CodingKey
    {
        case id
        case created
        case model
        case choices
        case object
        case usage
        case systemFingerprint = "system_fingerprint"
        case requestID = "request_id"
    }
}

struct Choice: Codable
{
    let index: Int
    let message: Message
    let logprobs: Logprobs?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case logprobs
        case finishReason = "finish_reason"
    }
}

struct Message: Codable
{
    let role: String
    let content: String?
}

struct Logprobs: Codable {
    let content: [TokenLogprob]?
    let refusal: [TokenLogprob]?
}

struct TokenLogprob: Codable {
    let token: String
    let logprob: Float
    let bytes: [Int]?
    let topLogprob: Float?

    enum CodingKeys: String, CodingKey {
        case token, logprob, bytes
        case topLogprob = "top_logprob"
    }
}


struct Usage: Codable
{
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    // subopenai
    let completionTokensDetails: CompletionTokensDetails?
    let promptTokensDetails: PromptTokensDetails?
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case completionTokensDetails = "completion_tokens_details"
        case promptTokensDetails = "prompt_tokens_details"
    }
}

struct CompletionTokensDetails: Codable
{
    let audioTokens: Int?
    let reasoningTokens: Int?
    
    enum CodingKeys: String,CodingKey {
        case audioTokens = "audio_tokens"
        case reasoningTokens = "reasoning_tokens"
    }
}

struct PromptTokensDetails: Codable
{
    let audioTokens: Int?
    let cachedTokens: Int?
    
    enum CodingKeys: String,CodingKey {
        case audioTokens = "audio_tokens"
        case cachedTokens = "cached_tokens"
    }
}
