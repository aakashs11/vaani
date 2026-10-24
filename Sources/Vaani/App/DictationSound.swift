// Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
import Foundation

enum DictationSound: String {
    case finished, cancelled, attention

    static let overrideDirectory = URL.applicationSupportDirectory
        .appendingPathComponent("Vaani/SoundOverrides", isDirectory: true)

    var url: URL? { url(in: Self.overrideDirectory) }

    func url(in directory: URL) -> URL? {
        let file = directory.appendingPathComponent(rawValue).appendingPathExtension("wav")
        return FileManager.default.isReadableFile(atPath: file.path) ? file : nil
    }
}
