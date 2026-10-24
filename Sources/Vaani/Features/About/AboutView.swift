// Vaani modification, 2026: separate derivative maintenance from original authorship.
import AppKit
import VaaniCore
import SwiftUI

struct AboutView: View {
    @Bindable var updater: AppUpdater
    let shortcut: DictationShortcut
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    private let repository = URL(string: "https://github.com/aakashs11/vaani")!

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    BrandMark(size: 72)
                    Text("Vaani (वाणी)").font(.title.weight(.semibold))
                    Text("Version \(version)").foregroundStyle(.secondary).textSelection(.enabled)
                    Text("Dictation for your Mac. Press \(shortcut.displayName), speak, and your words appear where you’re typing. Built-in speech models run on this Mac. Optional remote providers are used only when you select them.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            Section("Vaani") {
                LabeledContent("Maintained by", value: "Aakash")
                Link("Source code and releases", destination: repository)
                Link("Report a Vaani issue", destination: repository.appending(path: "issues"))
                Text("Updates are available from the Vaani repository. This build does not check for updates automatically.").foregroundStyle(.secondary)
            }
            Section("Origin and acknowledgements") {
                Link("Based on BetterWispr", destination: URL(string: "https://github.com/opennookorg/betterwispr")!)
                Text("BetterWispr was originally created by Kartik Labhshetwar and developed with its contributors. Vaani retains its native application foundation and existing speech-engine integrations.").foregroundStyle(.secondary)
                Text("Vaani’s changes include its own identity, additional shortcuts, data migration, diagnostics, recording review, and capture and vocabulary safeguards. Vaani does not claim to have trained a new speech model or proven higher recognition accuracy.").foregroundStyle(.secondary)
                Link("Full origin and changes", destination: repository.appending(path: "blob/main/docs/provenance.md"))
                Text("The combined Vaani derivative uses GPLv3. Original BetterWispr portions retain Apache 2.0 notices. Other components and model weights retain their own terms.").foregroundStyle(.secondary)
                Button("View licenses and acknowledgements") {
                    if let resources = Bundle.main.resourceURL {
                        NSWorkspace.shared.open(resources.appending(path: "Licenses", directoryHint: .isDirectory))
                    }
                }
            }
        }.formStyle(.grouped).toggleStyle(.switch)
    }
}
