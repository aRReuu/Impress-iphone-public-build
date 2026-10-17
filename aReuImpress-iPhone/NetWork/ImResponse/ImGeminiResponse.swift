//
//  ImGeminiResponse.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 11/23/24.
//

struct ImGeminiResponse: Codable
{
    let candidates:[Candidate]
    let usageMetadata:UsageMetadata
    let modelVersion:String
    
    struct Candidate:Codable
    {
        let content:Content
        let finishReason:String
        let avgLogprobs:Double
    }
    
    struct Content:Codable
    {
        let role:String
        let parts:[Part]
    }
    
    struct Part:Codable
    {
        let text:String
    }
    
    struct UsageMetadata:Codable
    {
        let promptTokenCount:Int
        let candidatesTokenCount:Int
        let totalTokenCount:Int
    }
}
