import Foundation
import Security

/// Small Keychain wrapper for tokens and the chip binding. Generic-password
/// items scoped to one service name (default: the app's bundle id),
/// accessible after first unlock, this device only.
/// Adapted from the Ingot package's Keychain helper.
struct Keychain: Sendable {
    let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.example.fathom") {
        self.service = service
    }

    func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Writes the value, or deletes the item when the value is empty.
    func write(_ account: String, _ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    func delete(_ account: String) { write(account, "") }
}
