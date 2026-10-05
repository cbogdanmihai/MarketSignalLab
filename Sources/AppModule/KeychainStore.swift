import Foundation
import Security

enum KeychainStore {
    private static let service = "com.marketsignallab.credentials"
    private static let account = "twelvedata.apiKey"

    static func saveAPIKey(
        _ value: String
    ) throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var insert = query
        insert[kSecValueData as String] = data

        let status = SecItemAdd(
            insert as CFDictionary,
            nil
        )

        guard status == errSecSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status)
            )
        }
    }

    static func loadAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        guard
            status == errSecSuccess,
            let data = result as? Data,
            let value = String(
                data: data,
                encoding: .utf8
            )
        else {
            return ""
        }

        return value
    }
}
