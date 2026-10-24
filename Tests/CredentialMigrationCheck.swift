import Foundation
import VaaniCore
func check(_ condition: Bool) { precondition(condition) }
@main struct CredentialMigrationCheck {
    static func main() throws {
        let connection = SpeechConnection(id: UUID(), api: .openAICompatible)
        let legacy = SpeechAPIKeyStore(service: "com.betterwispr.speech-api")
        let current = SpeechAPIKeyStore()
        defer { try? legacy.save("", for: connection); try? current.save("", for: connection) }
        try legacy.save("synthetic-test-secret", for: connection)
        check(try current.read(for: connection) == "synthetic-test-secret")
        check(try legacy.read(for: connection) == "synthetic-test-secret")
        try current.save("", for: connection)
        check(try current.read(for: connection) == nil)
        print("Credential migration checks passed: lazy copy, original retained during migration, explicit removal does not resurrect a legacy credential.")
    }
}
