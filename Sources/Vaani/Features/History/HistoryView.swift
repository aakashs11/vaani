// Vaani modification, 2026: product identity and compatibility; see docs/provenance.md.
import VaaniCore
import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel
    @State private var query = ""
    @State private var recordings = false
    @State private var pinnedOnly = false
    @State private var page = 0
    @State private var transcriptToDelete: Transcript?
    @State private var recordingToDelete: DictationEvidence?
    @State private var clearingRecordings = false

    private var filteredHistory: [Transcript] {
        query.isEmpty ? model.history : model.history.filter { $0.text.localizedStandardContains(query) }
    }
    private var filteredEvidence: [DictationEvidence] {
        model.evidence.filter {
            (!pinnedOnly || $0.pinned) && (query.isEmpty || $0.transcript.text.localizedStandardContains(query)
                || $0.transcript.rawText.localizedStandardContains(query) || ($0.failure?.localizedStandardContains(query) ?? false))
        }
    }
    private var count: Int { recordings ? filteredEvidence.count : filteredHistory.count }

    var body: some View {
        VStack(spacing: 0) {
            Picker("History", selection: $recordings) {
                Text("Dictations").tag(false)
                Text("Saved recordings").tag(true)
            }
            .pickerStyle(.segmented)
            .padding()
            if recordings {
                HStack {
                    Toggle("Pinned only", isOn: $pinnedOnly)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: model.evidence.reduce(0) { $0 + $1.audioBytes }, countStyle: .file))
                        .foregroundStyle(.secondary)
                    Button("Stop audio") { model.stopEvidencePlayback() }
                    Button("Delete all recordings", role: .destructive) { clearingRecordings = true }
                        .disabled(model.evidence.isEmpty)
                }
                .padding(.horizontal)
            }
            if !model.evidenceError.isEmpty {
                Text(model.evidenceError).foregroundStyle(.red).padding()
            }
            if count == 0 {
                ContentUnavailableView(recordings ? "No Saved Recordings" : "No Dictations",
                    systemImage: recordings ? "waveform" : "clock",
                    description: Text(recordings ? "New recordings appear here when Keep recent recordings is enabled in Settings. Older text history has no audio." : "Your saved dictations appear here."))
            } else {
                Form {
                    Section {
                        if recordings {
                            ForEach(Array(filteredEvidence.dropFirst(page * 50).prefix(50))) { record in
                                EvidenceRow(record: record,
                                    onPlay: { model.playEvidence(record) },
                                    onPin: { model.pinEvidence(record) },
                                    onDelete: { recordingToDelete = record },
                                    onReference: { model.saveEvidenceReference(record, text: $0) })
                            }
                        } else {
                            ForEach(Array(filteredHistory.dropFirst(page * 50).prefix(50))) { transcript in
                                TranscriptRow(transcript: transcript,
                                    onCopy: { model.copyTranscript(transcript) },
                                    onDelete: { transcriptToDelete = transcript },
                                    onEdit: { model.updateTranscript(transcript, text: $0) },
                                    onRestore: { model.restoreOriginal(transcript) }, expanded: true)
                            }
                        }
                    } header: {
                        Text("\(count) \(recordings ? "recordings" : "dictations")")
                    } footer: {
                        Text(recordings ? "The latest 50 unpinned recordings are kept. Pins stay until deleted. A model draft becomes a reviewed reference only after you check it against the audio." : "Text history is preserved when older audio expires. Select Saved recordings to listen and pin examples.")
                    }
                }
                .formStyle(.grouped)
                HStack {
                    Button("Previous") { page -= 1 }.disabled(page == 0)
                    Spacer()
                    Text("\(page * 50 + 1)–\(min((page + 1) * 50, count)) of \(count)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Next") { page += 1 }.disabled((page + 1) * 50 >= count)
                }.padding()
            }
        }
        .searchable(text: $query, prompt: "Search dictations")
        .onChange(of: query) { page = 0 }
        .onChange(of: recordings) { page = 0 }
        .onChange(of: pinnedOnly) { page = 0 }
        .onChange(of: count) { page = min(page, max(0, (count - 1) / 50)) }
        .onDisappear { model.stopEvidencePlayback() }
        .alert("Delete this dictation?", isPresented: Binding(get: { transcriptToDelete != nil }, set: { if !$0 { transcriptToDelete = nil } })) {
            Button("Cancel", role: .cancel) { transcriptToDelete = nil }
            Button("Delete", role: .destructive) {
                if let transcriptToDelete { model.deleteTranscript(transcriptToDelete) }
                transcriptToDelete = nil
            }
        } message: { Text("This removes its saved text and any associated recording, including a pin. It cannot be undone.") }
        .alert("Delete this recording?", isPresented: Binding(get: { recordingToDelete != nil }, set: { if !$0 { recordingToDelete = nil } })) {
            Button("Cancel", role: .cancel) { recordingToDelete = nil }
            Button("Delete", role: .destructive) {
                if let recordingToDelete { model.deleteEvidence(recordingToDelete) }
                recordingToDelete = nil
            }
        } message: { Text("This removes the audio and review record, including a pin. Your separate dictation history stays. It cannot be undone.") }
        .alert("Delete all saved recordings?", isPresented: $clearingRecordings) {
            Button("Cancel", role: .cancel) {}
            Button("Delete all", role: .destructive) { model.clearEvidence() }
        } message: { Text("This includes pinned recordings and reviewed references. Your separate text history stays. It cannot be undone.") }
    }
}

private struct EvidenceRow: View {
    let record: DictationEvidence
    let onPlay: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    let onReference: (String) -> Void
    @State private var reference = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.transcript.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                Text(record.transcript.modelName)
                if record.pinned { Image(systemName: "pin.fill").accessibilityLabel("Pinned") }
                Spacer()
                Button("Play", systemImage: "play.fill", action: onPlay)
                Button(record.pinned ? "Unpin" : "Pin for review", systemImage: record.pinned ? "pin.slash" : "pin", action: onPin)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }.font(.caption).buttonStyle(.borderless)
            if let failure = record.failure { Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            Text(record.transcript.text.isEmpty ? "No final transcript" : record.transcript.text).textSelection(.enabled)
            DisclosureGroup("Recognition and review") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before vocabulary changes").font(.caption).foregroundStyle(.secondary)
                    Text(record.recognition?.originalText ?? "This provider did not expose its original recognition.").textSelection(.enabled)
                    Text("After vocabulary changes").font(.caption).foregroundStyle(.secondary)
                    Text(record.transcript.rawText).textSelection(.enabled)
                    if let changes = record.recognition?.changes, !changes.isEmpty {
                        Text(changes.map { "\($0.original) → \($0.replacement)" }.joined(separator: ", ")).font(.caption)
                    }
                    TextField("Reference transcript checked against the audio", text: $reference, axis: .vertical)
                    Button("Save reviewed reference") { onReference(reference) }
                        .disabled(reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if record.reviewedAt != nil { Text("Reference reviewed against audio").font(.caption).foregroundStyle(.secondary) }
                }.padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .onAppear { reference = record.referenceText ?? "" }
    }
}

struct TranscriptRow: View {
    let transcript: Transcript
    let onCopy: () -> Void
    var onDelete: (() -> Void)?
    var onEdit: ((String) -> Void)?
    var onRestore: (() -> Void)?
    var expanded = false
    @State private var draft: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(transcript.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                Text("·")
                Text(durationLabel(transcript.duration)).monospacedDigit()
                if expanded {
                    Text("·")
                    Text(transcript.modelName)
                    Text("·")
                    Text(transcript.language == "auto" ? "Auto language" : transcript.language.uppercased())
                }
                Spacer()
                Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                    .help("Copy dictation")
                    .accessibilityLabel("Copy dictation")
                if onEdit != nil, draft == nil {
                    Button { draft = transcript.text } label: { Image(systemName: "pencil") }
                        .help("Fix dictation")
                        .accessibilityLabel("Fix dictation")
                }
                if let onDelete {
                    Button(action: onDelete) { Image(systemName: "trash") }
                        .help("Delete dictation")
                        .accessibilityLabel("Delete dictation")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .buttonStyle(.borderless)
            if let text = Binding($draft), let onEdit {
                TextEditor(text: text)
                    .font(.body)
                    .frame(minHeight: 60)
                    .accessibilityLabel("Dictation text")
                HStack {
                    Spacer()
                    Button("Cancel") { draft = nil }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") {
                        onEdit(text.wrappedValue)
                        draft = nil
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .controlSize(.small)
            } else {
                Text(transcript.text)
                    .lineLimit(expanded ? nil : 3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if expanded && transcript.text != transcript.rawText {
                DisclosureGroup("Original transcription") {
                    Text(transcript.rawText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let onRestore, transcript.text != transcript.rawText.trimmingCharacters(in: .whitespacesAndNewlines) {
                        Button("Use Original", action: onRestore)
                            .help("Replace the cleaned-up text with exactly what was transcribed")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
