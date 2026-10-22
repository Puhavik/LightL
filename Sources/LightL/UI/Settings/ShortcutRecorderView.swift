import SwiftUI
import Carbon
import AppKit

@MainActor
final class ShortcutRecorderController {
    var isRecording = false
    private var localMonitor: Any?

    func startRecording(onCaptured: @escaping (ShortcutModel) -> Void, onCancelled: @escaping () -> Void) {
        stopRecording()
        self.isRecording = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            // Handle Escape to cancel recording
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                onCancelled()
                return nil
            }

            var carbonModifiers: UInt32 = 0
            if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

            // Require at least one modifier
            if carbonModifiers != 0 {
                // Blacklist for system reserved shortcuts: reject standalone ⌘C, ⌘V, ⌘X, ⌘Z, ⌘A, ⌘Q, ⌘W, ⌘Space, ⌘Tab
                if ShortcutModel.isSystemReserved(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers) {
                    NSSound.beep()
                    return nil
                }

                let captured = ShortcutModel(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
                self.stopRecording()
                onCaptured(captured)
                return nil
            }

            NSSound.beep()
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    isolated deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

public struct ShortcutRecorderView: View {
    public let label: String
    @Binding public var shortcut: ShortcutModel
    public var defaultShortcut: ShortcutModel?

    @State private var controller = ShortcutRecorderController()
    @State private var isRecording = false
    @State private var isHovered = false
    @State private var isResetHovered = false

    public init(label: String, shortcut: Binding<ShortcutModel>, defaultShortcut: ShortcutModel? = nil) {
        self.label = label
        self._shortcut = shortcut
        self.defaultShortcut = defaultShortcut
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                if isRecording {
                    controller.stopRecording()
                    isRecording = false
                } else {
                    isRecording = true
                    controller.startRecording(
                        onCaptured: { newShortcut in
                            self.shortcut = newShortcut
                            self.isRecording = false
                        },
                        onCancelled: {
                            self.isRecording = false
                        }
                    )
                }
            }) {
                HStack(spacing: 5) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.red.opacity(0.8), radius: 4)

                        Text(L10n.tr(ru: "Запись...", en: "Recording..."))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)

                        Text("⎋ Esc")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    } else {
                        // macOS 27 Glass Keycaps
                        ForEach(shortcut.keyGlyphs, id: \.self) { glyph in
                            MacOS27Keycap(glyph)
                                .accessibilityLabel(accessibilityName(for: glyph))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isRecording ? Color.red.opacity(0.1) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isRecording ? Color.red.opacity(0.4) : (isHovered ? Color.primary.opacity(0.12) : Color.clear),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isRecording
                    ? L10n.tr(ru: "Идет запись сочетания клавиш. Нажмите Escape для отмены", en: "Recording shortcut. Press Escape to cancel")
                    : L10n.tr(ru: "Сочетание клавиш: \(shortcut.displayString). Нажмите для изменения", en: "Shortcut: \(shortcut.displayString). Click to change")
            )
            .onHover { isHovered = $0 }

            if let defaultShortcut = defaultShortcut {
                let isModified = (shortcut != defaultShortcut)
                Button(action: {
                    if isRecording {
                        controller.stopRecording()
                        isRecording = false
                    }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        self.shortcut = defaultShortcut
                    }
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L10n.tr(ru: "Сбросить", en: "Reset"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isModified ? .primary : .secondary.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isResetHovered
                                ? Color.primary.opacity(0.10)
                                : (isModified ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isModified
                                    ? Color.accentColor.opacity(0.3)
                                    : (isResetHovered ? Color.primary.opacity(0.12) : Color.clear),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { isResetHovered = $0 }
                .help(isModified
                    ? L10n.tr(ru: "Сбросить на сочетание по умолчанию (\(defaultShortcut.displayString))", en: "Reset to default shortcut (\(defaultShortcut.displayString))")
                    : L10n.tr(ru: "Уже установлено сочетание по умолчанию (\(defaultShortcut.displayString))", en: "Already set to default (\(defaultShortcut.displayString))"))
                .accessibilityLabel(L10n.tr(ru: "Сбросить сочетание клавиш на значение по умолчанию", en: "Reset shortcut to default"))
            }
        }
        .onDisappear {
            controller.stopRecording()
            isRecording = false
        }
    }

    private func accessibilityName(for glyph: String) -> String {
        switch glyph {
        case "⌃": return "Control"
        case "⌥": return "Option"
        case "⇧": return "Shift"
        case "⌘": return "Command"
        case "⏎": return "Return"
        case "⇥": return "Tab"
        case "⌫": return "Delete"
        case "⎋": return "Escape"
        default: return glyph
        }
    }
}
