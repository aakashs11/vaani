import Foundation

@main struct VocabularySafetyCheck {
    static func main() {
        for word in ["tell", "tall", "stall", "chart", "chat", "click", "scale", "skill", "safe", "save"] {
            precondition(CorrectionLearner.isCommon(word), "Ordinary word must not become a global correction: \(word)")
        }
        precondition(CorrectionLearner.corrections(from: "a stall", to: "a tall").isEmpty)
        let entries = [VocabularyEntry(phrase: "Postgres SQL", replacement: "PostgreSQL"),
                       VocabularyEntry(phrase: "organize thoughts prompt", replacement: String(repeating: "long prompt ", count: 20)),
                       VocabularyEntry(phrase: "my Flow referral", replacement: "Use my referral at https://example.com/referral"),
                       VocabularyEntry(phrase: "my email address", replacement: "aakash.mufc@gmail.com")]
        let hints = VocabularyProcessor.hints(entries)
        precondition(hints == ["PostgreSQL", "aakash.mufc@gmail.com"], "Snippets and URLs must not bias speech recognition")
        precondition(VocabularyProcessor.apply(entries, to: "organize thoughts prompt") == entries[1].replacement.trimmingCharacters(in: .whitespacesAndNewlines))
        print("PASS: ordinary-word learning rejected; snippets excluded from speech hints and preserved as intentional expansions")
    }
}
