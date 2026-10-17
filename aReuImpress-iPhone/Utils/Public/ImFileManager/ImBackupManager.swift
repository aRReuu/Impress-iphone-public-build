//
//  ImBackupManager.swift
//  aReuImpress-iPhone
//
//  Created by aReu on 10/1/25.
//  实现将本地数据库文件夹上传到GitHub私有仓库

import UIKit
import Foundation
import Security
import SystemConfiguration

final class ImBackupManager: NSObject {

    static let shared = ImBackupManager()

    // 备份在本地的源文件夹名称
    private let sourceFolderName = "ImpressDB"

    // GitHub仓库配置
    private let githubOwner = "aRReuu"
    private let githubRepo = "ImpressDBBackup"
    private let githubTokenKey = "com.impress.github.token"

    // 备份时间间隔（24小时）
    private let backupIntervalSeconds: TimeInterval = 24 * 60 * 60

    // MARK: - Keychain Methods

    /// 保存GitHub Token到Keychain
    func saveGitHubToken(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: githubTokenKey,
            kSecAttrAccount as String: "github_token",
            kSecValueData as String: token.data(using: .utf8)!
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            zcLog("保存GitHub Token失败: \(status)")
        } else {
            zcLog("GitHub Token已安全保存")
        }
    }

    /// 从Keychain读取GitHub Token
    func getGitHubToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: githubTokenKey,
            kSecAttrAccount as String: "github_token",
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// 删除Keychain中的GitHub Token
    func deleteGitHubToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: githubTokenKey,
            kSecAttrAccount as String: "github_token"
        ]

        SecItemDelete(query as CFDictionary)
        zcLog("GitHub Token已删除")
    }

    // MARK: - 备份到GitHub

    /// 上传到GitHub私有仓库
    func uploadToGitHub(from presenter: UIViewController, completion: @escaping (Error?) -> Void) {
        // 检查GitHub Token
        guard let token = getGitHubToken(), !token.isEmpty else {
            let error = NSError(domain: "ImBackupManager",
                              code: -100,
                              userInfo: [NSLocalizedDescriptionKey: "请先在设置中配置GitHub Token"])
            completion(error)
            return
        }

        // 获取数据库路径
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(NSError(domain: "ImBackupManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取文档目录"]))
            return
        }

        let dbURL = documentsURL.appendingPathComponent(sourceFolderName)

        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            completion(NSError(domain: "ImBackupManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "数据库文件不存在"]))
            return
        }

        // 后台执行上传
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // 将文件夹压缩为ZIP
                guard let zipData = self.createZipData(from: dbURL) else {
                    DispatchQueue.main.async {
                        completion(NSError(domain: "ImBackupManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "ZIP压缩失败"]))
                    }
                    return
                }

                // Base64编码
                let base64Data = zipData.base64EncodedString()

                // 上传到GitHub
                self.uploadToGitHubAPI(fileName: "ImpressDB_Backup_\(Date().timeIntervalSince1970).zip", base64Content: base64Data, token: token) { error in
                    DispatchQueue.main.async {
                        completion(error)
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    // MARK: - ZIP压缩

    private func createZipData(from folderURL: URL) -> Data? {
        do {
            let zipURL = try FileManager.default.archiveItem(at: folderURL, to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".zip"))
            let zipData = try Data(contentsOf: zipURL)
            try FileManager.default.removeItem(at: zipURL)
            return zipData
        } catch {
            zcLog("ZIP压缩失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - GitHub API

    private func uploadToGitHubAPI(fileName: String, base64Content: String, token: String, completion: @escaping (Error?) -> Void) {
        let url = URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/contents/\(fileName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters = [
            "message": "Backup ImpressDB - \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))",
            "content": base64Content,
            "branch": "main"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(error)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(NSError(domain: "ImBackupManager", code: -200, userInfo: [NSLocalizedDescriptionKey: "无效响应"]))
                return
            }

            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                completion(nil)
            } else {
                let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "未知错误"
                completion(NSError(domain: "ImBackupManager.GitHubUpload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub API错误: \(message)"]))
            }
        }
        task.resume()
    }
}
