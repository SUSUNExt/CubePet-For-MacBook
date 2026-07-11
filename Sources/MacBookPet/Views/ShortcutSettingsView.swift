import AppKit
import Carbon
import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var shortcutSettings: ShortcutSettings
    @ObservedObject var languageSettings: LanguageSettings
    let onClose: () -> Void

    @State private var draftShortcut: KeyboardShortcutDefinition
    @State private var isRecording = false
    @State private var message: String?

    init(
        shortcutSettings: ShortcutSettings,
        languageSettings: LanguageSettings,
        onClose: @escaping () -> Void
    ) {
        self.shortcutSettings = shortcutSettings
        self.languageSettings = languageSettings
        self.onClose = onClose
        _draftShortcut = State(initialValue: shortcutSettings.shortcut)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(languageSettings.text(.shortcutSettings))
                    .font(.title3.weight(.semibold))
                Text(languageSettings.shortcutText(.description))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(languageSettings.shortcutText(.currentShortcut))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ShortcutRecorderField(
                    shortcut: $draftShortcut,
                    isRecording: $isRecording,
                    prompt: languageSettings.shortcutText(.recordShortcut),
                    recordingPrompt: languageSettings.shortcutText(.pressNewShortcut),
                    onInvalidShortcut: {
                        message = languageSettings.shortcutText(.needsModifier)
                    }
                )
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button(languageSettings.shortcutText(.restoreDefault)) {
                    draftShortcut = .defaultShortcut
                    message = nil
                }

                Spacer()

                Button(languageSettings.shortcutText(.cancel)) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)

                Button(languageSettings.shortcutText(.save)) {
                    shortcutSettings.shortcut = draftShortcut
                    message = nil
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draftShortcut.isValid)
            }
        }
        .padding(22)
        .frame(width: 430, height: 260)
    }
}

private struct ShortcutRecorderField: View {
    @Binding var shortcut: KeyboardShortcutDefinition
    @Binding var isRecording: Bool
    let prompt: String
    let recordingPrompt: String
    let onInvalidShortcut: () -> Void

    var body: some View {
        Button {
            isRecording = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                Text(isRecording ? recordingPrompt : shortcut.displayString)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .background(
            ShortcutRecorderBridge(
                shortcut: $shortcut,
                isRecording: $isRecording,
                onInvalidShortcut: onInvalidShortcut
            )
            .frame(width: 0, height: 0)
        )
    }
}

private struct ShortcutRecorderBridge: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcutDefinition
    @Binding var isRecording: Bool
    let onInvalidShortcut: () -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onShortcut = { shortcut in
            self.shortcut = shortcut
            self.isRecording = false
        }
        view.onInvalidShortcut = onInvalidShortcut
        view.onCancel = {
            self.isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class RecorderView: NSView {
        var isRecording = false
        var onShortcut: ((KeyboardShortcutDefinition) -> Void)?
        var onInvalidShortcut: (() -> Void)?
        var onCancel: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }

            if event.keyCode == UInt16(kVK_Escape) {
                onCancel?()
                return
            }

            guard let shortcut = KeyboardShortcutDefinition.from(event: event), shortcut.isValid else {
                onInvalidShortcut?()
                return
            }

            onShortcut?(shortcut)
        }
    }
}
