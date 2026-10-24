// Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
import Foundation
import Security

public struct SpeechAPIKeyStore: Sendable {
    public static let notes = SpeechAPIKeyStore(service: "io.github.aakashs11.vaani.notes-api")
    private let service: String

    public init(service: String = "io.github.aakashs11.vaani.speech-api") { self.service = service }

    public func read(for connection: SpeechConnection) throws -> String? {
        var query = query(for: connection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            guard let legacyService, let key = try SpeechAPIKeyStore(service: legacyService).read(for: connection) else { return nil }
            try save(key, for: connection)
            return key
        }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { throw SpeechAPIError.keychain(status) }
        return key
    }

    public func save(_ key: String, for connection: SpeechConnection) throws {
        let query = query(for: connection)
        guard !key.isEmpty else {
            // Explicit removal must also remove the fallback, or the next read resurrects it.
            if let legacyService { try SpeechAPIKeyStore(service: legacyService).save("", for: connection) }
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw SpeechAPIError.keychain(status) }
            return
        }
        let values = [kSecValueData as String: Data(key.utf8)]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var item = query.merging(values) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SpeechAPIError.keychain(status) }
    }


    private var legacyService: String? {
        switch service {
        case "io.github.aakashs11.vaani.speech-api": "com.betterwispr.speech-api"
        case "io.github.aakashs11.vaani.notes-api": "com.betterwispr.notes-api"
        default: nil
        }
    }

    private func query(for connection: SpeechConnection) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: connection.keychainAccount,
         kSecAttrSynchronizable as String: false]
    }
}
