import SwiftUI
import AppKit

public struct StatusBarPopoverView: View {
    @Bindable var viewModel: StatusBarPopoverViewModel
    public let onOpenSettings: () -> Void
    public let onClose: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var hasCopied = false
    @State private var copyResetTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme

    public init(
        viewModel: StatusBarPopoverViewModel = StatusBarPopoverViewModel(),
        onOpenSettings: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onOpenSettings = onOpenSettings
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 8) {
            languageRow
            inputCard
            outputCard
            footerRow
        }
        .padding(12)
        .frame(width: 340, height: 360)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.40),
                    Color.white.opacity(colorScheme == .dark ? 0.01 : 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isInputFocused = true
            }
        }
    }

    private var languageRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(viewModel.detectedSourceLanguage ?? L10n.tr(ru: "Автоопределение", en: "Auto-detect"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))

            Spacer()

            Picker("", selection: Binding(
                get: { viewModel.targetLanguageCode },
                set: { viewModel.targetLanguageCode = $0 }
            )) {
                ForEach(LanguageModel.supportedLanguages) { lang in
                    Text("\(lang.localizedName) (\(lang.nativeName))").tag(lang.code)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(maxWidth: 160)
        }
        .padding(.horizontal, 4)
        .frame(height: 24)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                L10n.tr(ru: "Введите текст для перевода...", en: "Enter text to translate..."),
                text: Binding(
                    get: { viewModel.inputText },
                    set: {
                        viewModel.inputText = $0
                        viewModel.onInputTextChanged()
                    }
                ),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(4...5)
            .focused($isInputFocused)
            .font(.system(size: 12.5))

            Spacer(minLength: 0)

            if !viewModel.inputText.isEmpty {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.inputText = ""
                        viewModel.onInputTextChanged()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr(ru: "Очистить", en: "Clear"))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .macos27ContentCard(cornerRadius: 12)
        .frame(height: 108)
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.targetLanguage.localizedName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.65)
                        .frame(width: 14, height: 14)
                }

                Button(action: copyOutput) {
                    HStack(spacing: 3) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5))
                        if hasCopied {
                            Text(L10n.tr(ru: "Скопировано", en: "Copied"))
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundColor(hasCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.outputText.isEmpty)
                .help(L10n.tr(ru: "Скопировать перевод", en: "Copy translation"))
            }

            Divider()
                .opacity(0.4)

            ScrollView(.vertical, showsIndicators: true) {
                if let error = viewModel.errorMessage {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if !viewModel.outputText.isEmpty {
                    Text(viewModel.outputText)
                        .font(.system(size: 12.5))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(L10n.tr(ru: "Перевод появится здесь...", en: "Translation will appear here..."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .macos27ContentCard(cornerRadius: 12)
        .frame(height: 140)
    }

    private var footerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            let status = viewModel.statusState
            Circle()
                .fill(statusColor(status.color))
                .frame(width: 8, height: 8)
                .shadow(color: statusColor(status.color).opacity(0.6), radius: 2)
                .help(status.tooltip)

            Text(StatusBarController.appVersion)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)
                .help(L10n.tr(ru: "Версия LightL: \(StatusBarController.appVersion)", en: "LightL Version: \(StatusBarController.appVersion)"))

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.tr(ru: "Настройки...", en: "Settings..."))

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.tr(ru: "Завершить LightL", en: "Quit LightL"))
        }
        .padding(.horizontal, 4)
        .frame(height: 24)
    }

    private func statusColor(_ color: StatusDotColor) -> Color {
        switch color {
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        }
    }

    private func copyOutput() {
        guard !viewModel.outputText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(viewModel.outputText, forType: .string)
        hasCopied = true
        copyResetTask?.cancel()
        copyResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            hasCopied = false
        }
    }
}
