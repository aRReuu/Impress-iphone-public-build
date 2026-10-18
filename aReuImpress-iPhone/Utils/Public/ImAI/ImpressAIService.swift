import Foundation
import Security
import ImpressReviewCore

// New AI architecture. This is not the removed legacy Chat/LLM implementation.
// The UI manages provider-owned credentials; no API key value is Codable or logged.
enum ImpressAIServiceError: LocalizedError {
    case configuration, credential, invalidURL, unauthorized, status(Int), response, tooLarge, emptyModelList
    var errorDescription: String? {
        switch self {
        case .configuration: return V3L("请先在设置中配置并测试 AI 出题模型。")
        case .credential: return V3L("API Key 不可用，请重新保存密钥。")
        case .invalidURL: return V3L("API 地址不安全或不正确。")
        case .unauthorized: return V3L("API 授权失败，请检查密钥。")
        case .status(let code): return "AI API 请求失败（HTTP \(code)），原始数据未改变。"
        case .response: return V3L("模型响应不符合格式要求，未生成卡片。")
        case .tooLarge: return V3L("请求或响应超出安全长度限制。")
        case .emptyModelList: return V3L("服务商未返回模型列表，请手动输入模型 ID。")
        }
    }
}

enum ImpressAIKeychain {
    private static let service = "com.areu2.iphone.impress.ai.v1"

    static func write(_ value: String, id: UUID) throws {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty && token.utf8.count < 8_192 else { throw ImpressAIServiceError.credential }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw ImpressAIServiceError.credential }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw ImpressAIServiceError.credential
        }
    }

    static func read(id: UUID?) throws -> String {
        guard let id else { throw ImpressAIServiceError.credential }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let bytes = item as? Data,
              let secret = String(data: bytes, encoding: .utf8), !secret.isEmpty else {
            throw ImpressAIServiceError.credential
        }
        return secret
    }

    static func delete(id: UUID?) {
        guard let id else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class ImpressAIConfigStore {
    static let shared = ImpressAIConfigStore()
    private let url: URL
    private(set) var registry: ImpressAIRegistry

    private init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImpressV3", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        url = root.appendingPathComponent("AIConnections-v1.json")
        if let data = try? Data(contentsOf: url),
           let record = try? JSONDecoder().decode(ImpressAIRegistry.self, from: data),
           (try? record.validate()) != nil {
            registry = record
        } else {
            registry = try! ImpressAIRegistry()
        }
    }

    func replace(_ value: ImpressAIRegistry) throws {
        try value.validate()
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        registry = value
    }

    func update(_ operation: (inout ImpressAIRegistry) throws -> Void) throws {
        var next = registry
        try operation(&next)
        try replace(next)
    }
}

// Disable automatic redirection, which could otherwise forward an Authorization
// header or private note content to a new, unapproved endpoint.
private final class ImpressAINoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

actor ImpressAIHTTPClient {
    static let shared = ImpressAIHTTPClient()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 50
        config.timeoutIntervalForResource = 90
        config.httpMaximumConnectionsPerHost = 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config, delegate: ImpressAINoRedirect(),
                             delegateQueue: nil)
    }

    private func endpoint(_ connection: ImpressAIConnection, route: String) throws -> URL {
        guard connection.baseURL.scheme?.lowercased() == "https",
              connection.baseURL.user == nil, connection.baseURL.password == nil,
              connection.baseURL.query == nil, connection.baseURL.fragment == nil,
              (connection.baseURL.port == nil || connection.baseURL.port == 443) else {
            throw ImpressAIServiceError.invalidURL
        }
        return connection.baseURL.appendingPathComponent(route)
    }

    private func request(_ connection: ImpressAIConnection, path: String,
                         method: String, body: [String: Any]? = nil) throws -> URLRequest {
        var result = URLRequest(url: try endpoint(connection, route: path))
        result.httpMethod = method
        result.setValue("application/json", forHTTPHeaderField: "Accept")
        let secret = try ImpressAIKeychain.read(id: connection.credentialID)
        switch connection.apiProtocol {
        case .responses, .chatCompletions:
            result.setValue("Bearer " + secret, forHTTPHeaderField: "Authorization")
        case .anthropicMessages:
            result.setValue(secret, forHTTPHeaderField: "x-api-key")
            result.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .geminiGenerateContent:
            result.setValue(secret, forHTTPHeaderField: "x-goog-api-key")
        }
        if let body {
            let data = try JSONSerialization.data(withJSONObject: body)
            guard data.count <= 90_000 else { throw ImpressAIServiceError.tooLarge }
            result.httpBody = data
            result.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return result
    }

    private func execute(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ImpressAIServiceError.response }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ImpressAIServiceError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw ImpressAIServiceError.status(http.statusCode)
        }
        guard data.count < 1_000_000,
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImpressAIServiceError.response
        }
        return obj
    }

    // No inference of models' structured-output capability from this listing.
    func listModels(connection: ImpressAIConnection) async throws -> [String] {
        let obj = try await execute(request(connection, path: "models", method: "GET"))
        let entries = obj["data"] as? [[String: Any]] ??
                      obj["models"] as? [[String: Any]] ?? []
        let values = entries.compactMap { item -> String? in
            let raw = item["id"] as? String ?? item["name"] as? String ?? ""
            let name = raw.hasPrefix("models/") ? String(raw.dropFirst(7)) : raw
            return name.isEmpty ? nil : name
        }
        let cleaned = Array(Set(values)).sorted()
        guard !cleaned.isEmpty else { throw ImpressAIServiceError.emptyModelList }
        return Array(cleaned.prefix(300))
    }

    func complete(route: ImpressAIResolvedRoute, system: String,
                  user: String) async throws -> String {
        let c = route.connection
        let model = route.model.identifier
        guard system.utf8.count + user.utf8.count <= 65_000 else { throw ImpressAIServiceError.tooLarge }
        let payload: [String: Any]
        let path: String
        switch c.apiProtocol {
        case .responses:
            path = "responses"
            payload = ["model": model, "instructions": system, "input": user,
                       "store": false, "max_output_tokens": 2200]
        case .chatCompletions:
            path = "chat/completions"
            payload = ["model": model, "stream": false,
                       "response_format": ["type": "json_object"],
                       "messages": [
                           ["role": "system", "content": system],
                           ["role": "user", "content": user]
                       ]]
        case .anthropicMessages:
            path = "messages"
            payload = ["model": model, "max_tokens": 2200,
                       "system": system,
                       "messages": [["role": "user", "content": user]]]
        case .geminiGenerateContent:
            let encoded = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
            path = "models/" + encoded + ":generateContent"
            payload = [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["role": "user", "parts": [["text": user]]]],
                "generationConfig": ["responseMimeType": "application/json"]
            ]
        }
        let json = try await execute(request(c, path: path, method: "POST", body: payload))
        var answer: String?
        switch c.apiProtocol {
        case .responses:
            if let output = json["output"] as? [[String: Any]] {
                let parts = output.flatMap { $0["content"] as? [[String: Any]] ?? [] }
                answer = parts.filter { ($0["type"] as? String) == "output_text" }
                    .compactMap { $0["text"] as? String }.joined()
            }
            if answer?.isEmpty != false { answer = json["output_text"] as? String }
        case .chatCompletions:
            let choices = json["choices"] as? [[String: Any]] ?? []
            answer = (choices.first?["message"] as? [String: Any])?["content"] as? String
        case .anthropicMessages:
            let content = json["content"] as? [[String: Any]] ?? []
            answer = content.filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }.joined()
        case .geminiGenerateContent:
            let candidates = json["candidates"] as? [[String: Any]] ?? []
            let contents = candidates.first?["content"] as? [String: Any]
            answer = (contents?["parts"] as? [[String: Any]] ?? [])
                .compactMap { $0["text"] as? String }.joined()
        }
        guard let text = answer, !text.isEmpty, text.utf8.count < 70_000 else {
            throw ImpressAIServiceError.response
        }
        return text
    }

    /// Harmless connectivity + JSON probe. It is not a guarantee of factual correctness.
    func probeJSON(connection: ImpressAIConnection, model: ImpressAIModel) async throws -> Bool {
        let resolved = ImpressAIResolvedRoute(connection: connection, model: model)
        let output = try await complete(route: resolved,
              system: "Return a single valid JSON object and nothing else.",
              user: "Reply with exactly: {\"ok\":true}")
        guard let data = output.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return obj["ok"] as? Bool == true
    }
}
