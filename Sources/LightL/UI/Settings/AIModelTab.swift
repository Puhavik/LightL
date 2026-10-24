import SwiftUI
import AppKit

// MARK: - Tab 1: AI & Model Content

@MainActor
struct AIModelTab: View {
    @Bindable var settings = AppSettings.shared

    private enum ConnectionStatus {
        case success(String)
        case failure(String)
    }

    @State private var apiKeyInput: String = ""
    @State private var isTestingApiKey = false
    @State private var testResult: ConnectionStatus? = nil
    @State private var isShowingApiKey = false
    @State private var isCustomModel = false
    @State private var customModelText = ""
    @State private var modelDebounceTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 14) {
            // Card: API Key
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.tr(ru: "Ключ Google Gemini API", en: "Google Gemini API Key"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Link(L10n.tr(ru: "Получить ключ бесплатно ↗", en: "Get free key ↗"), destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.system(size: 11, weight: .medium))
                }

                HStack(spacing: 8) {
                    Group {
                        if isShowingApiKey || apiKeyInput.isEmpty {
                            TextField("AIzaSy...", text: $apiKeyInput)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .onSubmit {
                                    saveApiKey()
                                }
                        } else {
                            HStack {
                                Text(maskedApiKey)
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .frame(minHeight: 19)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isShowingApiKey = true
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                    Button(action: { isShowingApiKey.toggle() }) {
                        Image(systemName: isShowingApiKey ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        isShowingApiKey
                            ? L10n.tr(ru: "Скрыть API ключ", en: "Hide API key")
                            : L10n.tr(ru: "Показать API ключ", en: "Show API key")
                    )

                    Button(L10n.tr(ru: "Сохранить", en: "Save")) {
                        saveApiKey()
                    }
                    .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: true))
                }

                if settings.keychainSaveFailed {
                    Label(
                        L10n.tr(ru: "Не удалось сохранить ключ в Связке ключей: он будет утерян после перезапуска.",
                                en: "Could not save the key to the Keychain: it will be lost on restart."),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                }

                HStack(spacing: 12) {
                    Button(action: testConnection) {
                        HStack(spacing: 5) {
                            if isTestingApiKey {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 11))
                            }
                            Text(L10n.tr(ru: "Проверить ключ", en: "Test Key"))
                        }
                    }
                    .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: false))
                    .disabled(apiKeyInput.isEmpty || isTestingApiKey)

                    if let result = testResult {
                        switch result {
                        case .success(let msg):
                            MacOS27StatusBadge(title: msg, isSuccess: true, icon: "checkmark")
                        case .failure(let err):
                            MacOS27StatusBadge(title: err, isSuccess: false, icon: "exclamationmark.circle")
                        }
                    }
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)

            // Card: Model Selection
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr(ru: "Выбор модели Gemini", en: "Gemini Model Selection"))
                    .font(.system(size: 13, weight: .semibold))

                Picker(L10n.tr(ru: "Модель:", en: "Model:"), selection: Binding(
                    get: { isCustomModel ? "custom" : settings.selectedModelId },
                    set: { val in
                        if val == "custom" {
                            isCustomModel = true
                            commitCustomModel()
                        } else {
                            isCustomModel = false
                            modelDebounceTask?.cancel()
                            settings.selectedModelId = val
                        }
                    }
                )) {
                    ForEach(GeminiModelOption.availableModels) { option in
                        Text(option.localizedDisplayName).tag(option.modelId)
                    }
                    Divider()
                    Text(L10n.tr(ru: "Другая модель (ввести вручную)...", en: "Custom model (enter manually)...")).tag("custom")
                }
                .pickerStyle(.menu)

                if isCustomModel {
                    HStack {
                        Text(L10n.tr(ru: "ID модели:", en: "Model ID:"))
                            .font(.system(size: 12))
                        TextField(L10n.tr(ru: "например: gemini-2.5-flash", en: "e.g. gemini-2.5-flash"), text: $customModelText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                commitCustomModel()
                            }
                            .onChange(of: customModelText) { _, newVal in
                                modelDebounceTask?.cancel()
                                modelDebounceTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 600_000_000)
                                    guard !Task.isCancelled else { return }
                                    let trimmed = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty && settings.selectedModelId != trimmed {
                                        settings.selectedModelId = trimmed
                                    }
                                }
                            }
                    }
                } else if let current = GeminiModelOption.availableModels.first(where: { $0.modelId == settings.selectedModelId }) {
                    Text(current.localizedDescription)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
        .onAppear {
            apiKeyInput = settings.geminiApiKey
            let isKnown = GeminiModelOption.availableModels.contains { $0.modelId == settings.selectedModelId }
            if !isKnown {
                isCustomModel = true
                customModelText = settings.selectedModelId
            }
        }
        .onDisappear {
            saveApiKey()
            commitCustomModel()
        }
    }

    private var maskedApiKey: String {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 8 {
            return String(repeating: "•", count: trimmed.count)
        }
        let prefix = trimmed.prefix(6)
        let suffix = trimmed.suffix(4)
        return "\(prefix)••••••••••••\(suffix)"
    }

    private func commitCustomModel() {
        modelDebounceTask?.cancel()
        modelDebounceTask = nil
        let trimmed = customModelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && settings.selectedModelId != trimmed {
            settings.selectedModelId = trimmed
        }
    }

    private func saveApiKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != settings.geminiApiKey {
            settings.geminiApiKey = trimmed
        }
        testResult = nil
    }

    private func testConnection() {
        isTestingApiKey = true
        testResult = nil
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.selectedModelId

        Task {
            do {
                try await GeminiService.shared.testApiKey(apiKey: key, model: model)
                self.settings.geminiApiKey = key
                self.testResult = .success(L10n.tr(
                    ru: "Подключение успешно! Модель \(model) готова.",
                    en: "Connection successful! Model \(model) is ready."
                ))
                self.isTestingApiKey = false
            } catch {
                self.testResult = .failure(error.localizedDescription)
                self.isTestingApiKey = false
            }
        }
    }
}
