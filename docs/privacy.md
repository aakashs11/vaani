# Privacy

Vaani stores settings, vocabulary, transcript history, meetings, installed models, and optional recording evidence under `~/Library/Application Support/Vaani`. These files are local and unencrypted. Directory and file permissions restrict ordinary access to the current user, but they are not a substitute for device security or disk encryption.

Built-in local speech models process audio on your Mac. Downloads occur only after an explicit installation action. Missing or failed local models do not silently fall back to a remote service. Selected speech API connections upload audio to that endpoint. Selected editing/notes API or signed-in CLI providers receive text and any context explicitly enabled for that mode. Consult that provider's privacy terms.

The microphone remains off between dictations. Capture begins when you start a recording. Audio is normally temporary, but enabling saved recordings retains the latest 50 unpinned dictations and any pinned examples locally. Saved evidence can contain audio, original recognition, final text, vocabulary/settings snapshots, a reference entered by the user, and timing metadata. Pins remain until deleted and can increase disk usage. Disabling retention stops new saves without erasing existing evidence. Deleting a history record removes its associated evidence. Deleting only a saved recording leaves text history. Cancellation discards audio unless you explicitly restore the cancelled dictation with Undo.

Meeting notes can capture microphone and system audio after explicit start. Selected providers determine whether meeting audio/text is processed locally or remotely. Context features are separately controlled. Secure-input and clipboard safeguards remain in place.

Diagnostic events are stored in `~/Library/Logs/io.github.aakashs11.vaani`, with bounded rotation. They contain session/configuration/timing metadata, not audio or transcript text. Diagnostic export is a user action and produces local files. Review and redact them before sharing.

API keys remain in Keychain. Legacy credentials are copied through Keychain APIs on first use, never through plaintext exports. Migration leaves the legacy data copy intact for recovery. To erase all retained information, remove both the current and legacy/recovery copies only after confirming you no longer need them, and remove unwanted Keychain credentials through the system interface.

Automatic upstream updates are disabled. Vaani does not add a telemetry service. The destination app receiving a dictated paste handles the resulting text under its own policies.
