// Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
import Foundation

public struct VocabularyChange: Codable, Equatable, Sendable {
    public var original: String
    public var replacement: String
    public init(original: String, replacement: String) {
        self.original = original
        self.replacement = replacement
    }
}

/// The recognizer output before vocabulary rescoring, when the provider exposes it.
public struct RecognitionDetails: Codable, Equatable, Sendable {
    public var originalText: String
    public var changes: [VocabularyChange]
    public init(originalText: String, changes: [VocabularyChange] = []) {
        self.originalText = originalText
        self.changes = changes
    }
}
