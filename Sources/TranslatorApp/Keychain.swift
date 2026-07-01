import Foundation
import Security

/// macOS 钥匙串读写 API Key。比 UserDefaults 明文存储安全得多。
/// 用 generic password 项，account = 各服务商标识，service = 固定 bundle 前缀。
enum Keychain {
    private static let service = "com.local.translator.apikey"

    /// 读取某个 account（一般是 provider 标识）对应的密钥。
    static func read(account: String) -> String? {
        var query: [String: Any] = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                Log.warn("Keychain read 失败 status=\(status) account=\(account)")
            }
            return nil
        }
        return str
    }

    /// 写入/更新密钥。空字符串视为删除。
    @discardableResult
    static func write(_ value: String, account: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return delete(account: account)
        }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let query = baseQuery(account: account)
        let attrs: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            // 仅在解锁后可访问，且不随 iCloud 同步
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                Log.warn("Keychain add 失败 status=\(addStatus) account=\(account)")
            }
            return addStatus == errSecSuccess
        }

        Log.warn("Keychain update 失败 status=\(updateStatus) account=\(account)")
        return false
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
