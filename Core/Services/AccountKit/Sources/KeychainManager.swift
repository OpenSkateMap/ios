public import Foundation
import Security
import Synchronization

// MARK: - KeychainManager

public struct KeychainManager: Sendable {
    public var load: @Sendable (_ key: String) throws -> Data?
    public var save: @Sendable (_ data: Data, _ key: String) throws -> Void
    public var delete: @Sendable (_ key: String) throws -> Void

    public init(load: @escaping @Sendable (_ key: String) throws -> Data?,
                save: @escaping @Sendable (_ data: Data, _ key: String) throws -> Void,
                delete: @escaping @Sendable (_ key: String) throws -> Void) {
        self.load = load
        self.save = save
        self.delete = delete
    }
}

// MARK: - KeychainError

public struct KeychainError: Error, Equatable {
    public let status: OSStatus
}

extension KeychainManager {
    public static func live(service: String) -> KeychainManager {
        @Sendable
        func query(_ key: String) -> [CFString: Any] {
            [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: key]
        }

        return KeychainManager(
            load: { key in
                var query = query(key)
                query[kSecReturnData] = true
                query[kSecMatchLimit] = kSecMatchLimitOne
                var result: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                switch status {
                case errSecSuccess: return result as? Data
                case errSecItemNotFound: return nil
                default: throw KeychainError(status: status)
                }
            },
            save: { data, key in
                let attributes: [CFString: Any] = [
                    kSecValueData: data,
                    kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                ]
                var status = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
                if status == errSecItemNotFound {
                    status = SecItemAdd(query(key).merging(attributes) { $1 } as CFDictionary, nil)
                }
                guard status == errSecSuccess else {
                    throw KeychainError(status: status)
                }
            },
            delete: { key in
                let status = SecItemDelete(query(key) as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw KeychainError(status: status)
                }
            },
        )
    }

    public static func inMemory(_ items: [String: Data] = [:]) -> KeychainManager {
        let items = Mutex(items)
        return KeychainManager(
            load: { key in items.withLock { $0[key] } },
            save: { data, key in items.withLock { $0[key] = data } },
            delete: { key in _ = items.withLock { $0.removeValue(forKey: key) } },
        )
    }
}
