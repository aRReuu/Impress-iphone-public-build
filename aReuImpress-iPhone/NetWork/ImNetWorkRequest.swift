//
//  ImNetWorkRequest.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 11/1/24.
//

import UIKit

final class ImNetWorkRequest:NSObject
{

    static let shared = ImNetWorkRequest()

    /// 热度参数
    let llmTemperature: CGFloat = 1.0
}

// MARK: - Chat Request
extension ImNetWorkRequest {

    /// 获取当前用户设置的系统提示词
    /// - Returns: 用户自定义的系统提示词，如果未设置则返回默认的费曼式提示词
    func getCurrentSystemPrompt() -> String {
        let settingsViewModel = ImSettingsViewModel()
        return settingsViewModel.systemPrompt
    }

    /// 发起聊天请求
    /// - Parameters:
    ///   - messages: 包含对话历史的消息数组
    ///   - llm: 当前使用的大语言模型配置
    ///   - systemPrompt: 可选的系统提示词，用于设置上下文，默认值为通用助手提示
    ///   - completion: 完成回调，返回结果或错误, Item1: content, Item2: usage
    func requestPollingChat(messages: [[String: String]],
                            llm: ImLLMModel,
                            systemPrompt: String? = nil,
                            completion: @escaping (ImHandlerResult<(content: String, usage: Usage?)>) -> Void) {
        // 检查是否启用模拟数据
        let settingsViewModel = ImSettingsViewModel()
        if settingsViewModel.isMockDataEnabled {
            // 使用模拟数据，进行网络延迟模拟
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let mockResponse = self.getMockDataResponse()
                completion(.success(mockResponse))
            }
            return
        }

        guard let apiKey = llm.apiKey, !apiKey.isEmpty,
              let modelIdentifier = llm.modelIdentifier, !modelIdentifier.isEmpty,
              let baseURL = llm.baseURL, let url = URL(string: baseURL) else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "com.impress.error", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "模型配置不完整：缺少 API Key、模型标识或 Base URL。"
                ])))
            }
            return
        }

        // 增加对 OpenRouter 的兼容性 Headers
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]

        var messagesWithSystem = messages
        if let prompt = systemPrompt, !prompt.isEmpty {
            messagesWithSystem.insert(["role": "system", "content": prompt], at: 0)
        }

        let parameters: [String: Any] = [
            "model": modelIdentifier,
            "temperature": llm.temperature ?? llmTemperature,
            "messages": messagesWithSystem
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        // Privacy: NEVER log the Authorization header, user's question,
        // answer, personal notes or raw request body, including in Debug.

        // Create session with timeout configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 60.0
        let session = URLSession(configuration: config)

        // Use synchronous dataTask with completion handler
        let dataTask = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? httpResponse.allHeaderFields["content-type"] as? String
                        if contentType?.contains("application/json") == true {
                            do {
                                guard let data = data else {
                                    completion(.failure(NSError(domain: "com.impress.error", code: -3, userInfo: [NSLocalizedDescriptionKey: "Empty response data"])))
                                    return
                                }
                                let responseModel = try JSONDecoder().decode(ImpressResponse.self, from: data)
                                if let content = responseModel.choices.first?.message.content {
                                    completion(.success((content: content, usage: responseModel.usage)))
                                } else {
                                    completion(.failure(NSError(domain: "com.impress.error", code: -2, userInfo: [NSLocalizedDescriptionKey: "响应数据结构不符合预期，缺少有效内容。"])))
                                }
                            } catch {
                                // Provider response bodies may contain personal
                                // prompts or provider-generated credentials.
                                // Never print, store or expose raw response bytes.
                                let errorMessage = "AI 响应格式解析失败：\(error.localizedDescription)"
                                completion(.failure(NSError(domain: "com.impress.error", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                            }
                        } else {
                            completion(.failure(NSError(domain: "com.impress.error", code: -5, userInfo: [NSLocalizedDescriptionKey: "HTTP 响应不是有效的 JSON 格式。"])))
                        }
                    } else {
                        let errorMessage = "AI 服务请求失败（HTTP \(httpResponse.statusCode)）。请检查模型配置、余额和网络连接。"
                        // Do not log raw responses, private prompts or API keys.
                        completion(.failure(NSError(domain: "com.impress.error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    }
                } else {
                    completion(.failure(NSError(domain: "com.impress.error", code: -4, userInfo: [NSLocalizedDescriptionKey: "没有收到有效响应"])))
                }
            }

            // Clean up session
            session.invalidateAndCancel()
        }

        dataTask.resume()
    }
}
