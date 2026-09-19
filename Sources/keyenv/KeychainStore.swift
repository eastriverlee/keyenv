#if os(macOS)
import Foundation
import Security

struct KeychainStore: SecretStore {
    private func query(forName name: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: name,
        ]
    }

    private func failure(_ status: OSStatus) -> StoreFailure {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
        return .backendFailed("keychain returned \(status): \(message)")
    }

    func store(_ value: String, forName name: String) throws {
        let data = Data(value.utf8)
        let existing = query(forName: name)
        let updateStatus = SecItemUpdate(
            existing as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw failure(updateStatus) }

        var creation = existing
        creation[kSecValueData as String] = data
        creation[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        creation[kSecAttrLabel as String] = "\(serviceName): \(name)"
        let addStatus = SecItemAdd(creation as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw failure(addStatus) }
    }

    func read(forName name: String) throws -> String {
        var lookup = query(forName: name)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecItemNotFound { throw StoreFailure.nameNotStored(name) }
        guard status == errSecSuccess else { throw failure(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw failure(errSecDecode)
        }
        return value
    }

    func remove(forName name: String) throws {
        let status = SecItemDelete(query(forName: name) as CFDictionary)
        if status == errSecItemNotFound { throw StoreFailure.nameNotStored(name) }
        guard status == errSecSuccess else { throw failure(status) }
    }

    func storedNames() throws -> [String] {
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var items: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &items)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw failure(status) }
        guard let attributes = items as? [[String: Any]] else { return [] }
        return attributes.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }
}
#endif
