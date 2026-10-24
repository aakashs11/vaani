import BetterWisprCore
import SwiftUI

struct AboutView: View {
    @Bindable var updater: AppUpdater
    let shortcut: DictationShortcut
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    private let repository = URL(string: "https://github.com/opennookorg/betterwispr")!

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    BrandMark(size: 72)
                    Text("वाणी").font(.title.weight(.semibold))
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Private dictation for your Mac. Press \(shortcut.displayName) in any app, speak, and your words appear where you’re typing. Speech is processed on this Mac.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 480)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Updates") {
                Text("This personal build is updated from your Vaani project. Automatic upstream updates are disabled to preserve your customizations.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Link("View on GitHub", destination: repository)
                } label: {
                    Text("Source code")
                    Text("Browse the code and every release.")
                }
                LabeledContent {
                    Link("Open an Issue", destination: repository.appending(path: "issues"))
                } label: {
                    Text("Feedback")
                    Text("Report a bug or suggest a feature.")
                }
            } header: {
                Text("Open Source")
            } footer: {
                Text("वाणी is your personal build of BetterWispr, free and open source under the Apache 2.0 license.")
                    .foregroundStyle(.secondary)
            }

            Section("Credits") {
                LabeledContent("Created by", value: "Kartik Labhshetwar")
                LabeledContent("Follow along") {
                    Link("@code_kartik on X", destination: URL(string: "https://x.com/code_kartik")!)
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }
}
