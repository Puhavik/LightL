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
                let captured = ShortcutModel(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
                self.stopRecording()
                onCaptured(captured)
                return nil
            }

            return event
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

public struct ShortcutRecorderView: View {
    public let label: String
    @Binding public var shortcut: ShortcutModel

    @State private var controller = ShortcutRecorderController()
    @State private var isRecording = false
    @State private var isHovered = false

    public init(label: String, shortcut: Binding<ShortcutModel>) {
        self.label = label
        self._shortcut = shortcut
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
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
