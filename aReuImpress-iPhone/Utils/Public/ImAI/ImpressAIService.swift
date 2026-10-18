import Foundation
import Security
import ImpressReviewCore

// New AI architecture. This is not the removed legacy Chat/LLM implementation.
// The UI manages provider-owned credentials; no API key value is Codable or logged.
enum ImpressAIServiceError: LocalizedError {
    case configuration, credential, invalidURL, unauthorized, status(Int), response, tooLarge, emptyModelList
    case freeModelOnly
    var errorDescription: String? {
        switch self {
        case .configuration: return V3L("请先在设置中配置并测试 AI 出题模型。")
        case .freeModelOnly: return V3L("本 QA 版只允许 OpenCode 官方免费模型；推荐添加「OpenCode 免费模型（测试）」，不需要密钥。使用 Keychain 密钥时也只允许相同的免费型号。")
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

/// Ephemeral conversation turns. No conversation is persisted to app backups
/// or turned into knowledge automatically.
enum ImpressAIChatRole: String, Sendable {
    case user, assistant
}

struct ImpressAIChatTurn: Sendable {
    let role: ImpressAIChatRole
    let text: String
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
                         method: String, wireProtocol: ImpressAIProtocol,
                         body: [String: Any]? = nil) throws -> URLRequest {
        try connection.effectiveEndpoints.validate()
        guard wireProtocol == .geminiGenerateContent ||
              ImpressAIEndpointPaths.safePath(path) else {
            throw ImpressAIServiceError.invalidURL
        }
        var result = URLRequest(url: try endpoint(connection, route: path))
        result.httpMethod = method
        result.setValue("application/json", forHTTPHeaderField: "Accept")
        // Auth is configured per connection, independently of each model's
        // payload protocol. This supports Bearer-auth Messages gateways.
        let auth = connection.effectiveAuthentication
        if auth != .noAuthentication {
            let secret = try ImpressAIKeychain.read(id: connection.credentialID)
            switch auth {
            case .bearer:
                result.setValue("Bearer " + secret, forHTTPHeaderField: "Authorization")
            case .rawAuthorization:
                result.setValue(secret, forHTTPHeaderField: "Authorization")
            case .apiKeyHeader:
                result.setValue(secret, forHTTPHeaderField: "x-api-key")
            case .googleAPIKeyHeader:
                result.setValue(secret, forHTTPHeaderField: "x-goog-api-key")
            case .customHeader:
                guard ImpressAIRegistry.safeCustomHeader(connection.customHeaderName ?? "") else {
                    throw ImpressAIServiceError.invalidURL
                }
                result.setValue(secret, forHTTPHeaderField: connection.customHeaderName!)
            case .noAuthentication:
                break
            }
        }
        if wireProtocol == .anthropicMessages {
            result.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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
        let path = connection.effectiveEndpoints.modelsPath
        guard !path.isEmpty else { throw ImpressAIServiceError.emptyModelList }
        let obj = try await execute(request(connection, path: path, method: "GET",
                                            wireProtocol: connection.apiProtocol))
        let entries = obj["data"] as? [[String: Any]] ??
                      obj["models"] as? [[String: Any]] ?? []
        let values = entries.compactMap { item -> String? in
            let raw = item["id"] as? String ?? item["name"] as? String ?? ""
            let name = raw.hasPrefix("models/") ? String(raw.dropFirst(7)) : raw
            return name.isEmpty ? nil : name
        }
        let cleaned = Array(Set(values)).sorted()
        // The anonymous QA profile must never present paid models as choices.
        let filtered = connection.provider == .openCode &&
            connection.effectiveAuthentication == .noAuthentication
            ? cleaned.filter(ImpressAIOpenCodeFreeQA.allowedForCatalog)
            : cleaned
        guard !filtered.isEmpty else { throw ImpressAIServiceError.emptyModelList }
        return Array(filtered.prefix(300))
    }

    func complete(route: ImpressAIResolvedRoute, system: String,
                  user: String) async throws -> String {
        // No app-held API keys or charged models are reachable through QA.
        guard (try? ImpressAIOpenCodeFreeQA.validate(route)) != nil else {
            throw ImpressAIServiceError.freeModelOnly
        }
        let c = route.connection
        let model = route.model.identifier
        guard system.utf8.count + user.utf8.count <= 65_000 else { throw ImpressAIServiceError.tooLarge }
        var payload: [String: Any]
        let path: String
        let wire = route.effectiveProtocol
        switch wire {
        case .responses:
            path = c.effectiveEndpoints.responsesPath
            payload = ["model": model, "instructions": system, "input": user,
                       "store": false, "max_output_tokens": 2200]
        case .chatCompletions:
            path = c.effectiveEndpoints.chatPath
            payload = ["model": model, "stream": false,
                       "messages": [
                           ["role": "system", "content": system],
                           ["role": "user", "content": user]
                       ]]
            if route.model.jsonMode != .promptOnly {
                payload["response_format"] = ["type": "json_object"]
            }
        case .anthropicMessages:
            path = c.effectiveEndpoints.messagesPath
            payload = ["model": model, "max_tokens": 2200,
                       "system": system,
                       "messages": [["role": "user", "content": user]]]
        case .geminiGenerateContent:
            let characters = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
            let encoded = model.addingPercentEncoding(withAllowedCharacters: characters) ?? model
            path = "models/" + encoded + ":generateContent"
            payload = [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["role": "user", "parts": [["text": user]]]],
                "generationConfig": route.model.jsonMode == .promptOnly ? [:] :
                                    ["responseMimeType": "application/json"]
            ]
        }
        let json = try await execute(request(c, path: path, method: "POST",
                                             wireProtocol: wire, body: payload))
        var answer: String?
        switch wire {
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

    /// Actual native text conversation, NOT the structured JSON question API.
    /// Only an explicit Send tap reaches this method. No Vault read/write tools.
    func converse(route: ImpressAIResolvedRoute, system: String,
                  turns: [ImpressAIChatTurn]) async throws -> String {
        guard !turns.isEmpty, turns.last?.role == .user, turns.count <= 20,
              system.utf8.count <= 4_000,
              turns.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 && $0.text.utf8.count <= 12_000 }),
              turns.reduce(0, { $0 + $1.text.utf8.count }) <= 55_000 else {
            throw ImpressAIServiceError.tooLarge
        }
        guard (try? ImpressAIOpenCodeFreeQA.validate(route)) != nil else {
            throw ImpressAIServiceError.freeModelOnly
        }
        let connection = route.connection
        let model = route.model.identifier
        let wire = route.effectiveProtocol
        let endpointPath: String
        let payload: [String: Any]
        switch wire {
        case .responses:
            endpointPath = connection.effectiveEndpoints.responsesPath
            payload = ["model": model, "instructions": system,
                       "input": turns.map { ["role": $0.role.rawValue, "content": $0.text] },
                       "store": false, "max_output_tokens": 1400]
        case .chatCompletions:
            endpointPath = connection.effectiveEndpoints.chatPath
            let messages: [[String: String]] = [["role": "system", "content": system]] +
                turns.map { ["role": $0.role.rawValue, "content": $0.text] }
            payload = ["model": model, "messages": messages, "stream": false]
        case .anthropicMessages:
            endpointPath = connection.effectiveEndpoints.messagesPath
            payload = ["model": model, "system": system, "max_tokens": 1400,
                       "messages": turns.map {
                           ["role": $0.role.rawValue, "content": $0.text]
                       }]
        case .geminiGenerateContent:
            let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
            let safeModel = model.addingPercentEncoding(withAllowedCharacters: allowed) ?? model
            endpointPath = "models/" + safeModel + ":generateContent"
            payload = ["systemInstruction": ["parts": [["text": system]]],
                       "contents": turns.map { item in
                           ["role": item.role == .assistant ? "model" : "user",
                            "parts": [["text": item.text]]]
                       }]
        }
        let response = try await execute(request(connection, path: endpointPath,
                            method: "POST", wireProtocol: wire, body: payload))
        let text: String?
        switch wire {
        case .responses:
            let items = response["output"] as? [[String: Any]] ?? []
            let parts = items.flatMap { $0["content"] as? [[String: Any]] ?? [] }
            let combined = parts.filter { $0["type"] as? String == "output_text" }
                .compactMap { $0["text"] as? String }.joined()
            text = combined.isEmpty ? response["output_text"] as? String : combined
        case .chatCompletions:
            let choices = response["choices"] as? [[String: Any]] ?? []
            text = (choices.first?["message"] as? [String: Any])?["content"] as? String
        case .anthropicMessages:
            let parts = response["content"] as? [[String: Any]] ?? []
            text = parts.filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }.joined()
        case .geminiGenerateContent:
            let responses = response["candidates"] as? [[String: Any]] ?? []
            let content = responses.first?["content"] as? [String: Any]
            text = (content?["parts"] as? [[String: Any]] ?? [])
                .compactMap { $0["text"] as? String }.joined()
        }
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, value.utf8.count <= 65_000 else {
            throw ImpressAIServiceError.response
        }
        return value
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
