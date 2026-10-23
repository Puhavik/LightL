import SwiftUI
import AppKit

// MARK: - Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case aiModel = "ai_model"
    case translation = "translation"
    case rewrite = "rewrite"
    case permissions = "permissions"
    case appearance = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiModel: return L10n.tr(ru: "ИИ и Модель", en: "AI & Model")
        case .translation: return L10n.tr(ru: "Перевод", en: "Translation")
        case .rewrite: return L10n.tr(ru: "Исправление", en: "Correction")
        case .permissions: return L10n.tr(ru: "Разрешения", en: "Permissions")
        case .appearance: return L10n.tr(ru: "Оформление", en: "Appearance")
        }
    }

    var icon: String {
        switch self {
        case .aiModel: return "sparkles"
        case .translation: return "character.book.closed.fill"
        case .rewrite: return "text.badge.checkmark"
        case .permissions: return "lock.shield.fill"
        case .appearance: return "slider.horizontal.2.square.on.square"
        }
    }

    var iconGradient: [Color] {
        switch self {
        case .aiModel:
            return [Color(red: 0.62, green: 0.38, blue: 0.98), Color(red: 0.44, green: 0.22, blue: 0.88)]
        case .translation:
            return [Color(red: 0.18, green: 0.58, blue: 0.98), Color(red: 0.08, green: 0.38, blue: 0.85)]
        case .rewrite:
            return [Color(red: 0.15, green: 0.78, blue: 0.55), Color(red: 0.08, green: 0.58, blue: 0.42)]
        case .permissions:
            return [Color(red: 0.98, green: 0.58, blue: 0.18), Color(red: 0.88, green: 0.42, blue: 0.08)]
        case .appearance:
            return [Color(red: 0.98, green: 0.35, blue: 0.65), Color(red: 0.82, green: 0.18, blue: 0.48)]
        }
    }
}

// MARK: - SettingsView (Main Container)

public struct SettingsView: View {
    @Bindable var settings = AppSettings.shared
    @State private var selectedTab: SettingsTab

    public init() {
        _selectedTab = State(initialValue: .aiModel)
    }

    init(initialTab: SettingsTab) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Edge-to-Edge Liquid Glass Sidebar (macOS 27 HIG standard)
            sidebarView
                .frame(width: 205)

            // Divider edge
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
                .ignoresSafeArea()

            // Main Content Layer
            detailContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 490)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if TextCaptureService.isAccessibilityGranted() {
                HotKeyManager.shared.recheckDoubleCmdCMonitor()
            }
        }
    }

    // MARK: - Sidebar (macOS 27 Edge-to-Edge with Colored SF Symbols)
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Window Traffic Light Safe Area
            HStack {
                Spacer()
            }
            .frame(height: 12)

            // App Brand Banner
            HStack(spacing: 8) {
                Image(nsImage: NSImage.appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                Text("LightL")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(height: 32)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            // Tab Navigation Items
            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 10) {
                            // Signature macOS 27 Colored Sidebar Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: tab.iconGradient,
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 22, height: 22)
                                    .shadow(color: tab.iconGradient.first?.opacity(0.3) ?? .clear, radius: 2, x: 0, y: 1)

                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            Text(tab.title)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .primary : .secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Quick Status Footer
            HStack(spacing: 6) {
                Circle()
                    .fill(settings.geminiApiKey.isEmpty ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(settings.geminiApiKey.isEmpty
                    ? L10n.tr(ru: "Ключ API не задан", en: "API Key Missing")
                    : L10n.tr(ru: "API подключен", en: "API Connected"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }

    // MARK: - Detail Content Layer (Content Layer on Solid/Tinted Cards)
    private var detailContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(selectedTab.title)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // Content Body
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .aiModel:
                        AIModelTab()
                    case .translation:
                        TranslationTab()
                    case .rewrite:
                        RewriteTab()
                    case .permissions:
                        PermissionsTab()
                    case .appearance:
                        AppearanceTab()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

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
                                .onChange(of: apiKeyInput) { _, _ in
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
        if !trimmed.isEmpty || !settings.geminiApiKey.isEmpty {
            settings.geminiApiKey = trimmed
        }
        testResult = nil
    }

    private func testConnection() {
        isTestingApiKey = true
        testResult = nil
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.geminiApiKey = key
        let model = settings.selectedModelId

        Task {
            do {
                try await GeminiService.shared.testApiKey(apiKey: key, model: model)
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

// MARK: - Tab 2: Translation Content

struct TranslationTab: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 14) {
            // Target Language Card
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.tr(ru: "Целевой язык перевода", en: "Target Translation Language"))
                    .font(.system(size: 13, weight: .semibold))

                Picker(L10n.tr(ru: "Язык:", en: "Language:"), selection: $settings.targetLanguageCode) {
                    ForEach(LanguageModel.supportedLanguages) { lang in
                        Text("\(lang.localizedName) (\(lang.nativeName))").tag(lang.code)
                    }
                }
                .pickerStyle(.menu)

                Text(L10n.tr(ru: "Язык исходного фрагмента определяется моделью автоматически.", en: "Source language is detected automatically by the model."))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)

            // Shortcuts Card
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr(ru: "Горячие клавиши", en: "Keyboard Shortcuts"))
                    .font(.system(size: 13, weight: .semibold))

                ShortcutRecorderView(
                    label: L10n.tr(ru: "Всплывающее окно перевода:", en: "Translation popover:"),
                    shortcut: $settings.translateShortcut,
                    defaultShortcut: ShortcutModel.defaultTranslate
                )

                Divider()

                Toggle(L10n.tr(ru: "Быстрое двойное нажатие ⌘ + C", en: "Double-tap ⌘ + C"), isOn: $settings.doubleCmdCEnabled)
                    .font(.system(size: 13))

                Text(L10n.tr(
                    ru: "При быстром двойном нажатии ⌘+C выделенный фрагмент текста копируется и сразу открывается перевод в плавающем окне.",
                    en: "Quickly pressing ⌘+C twice copies the selected text and immediately displays the translation in a floating window."
                ))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
    }
}

// MARK: - Tab 3: Rewrite Content

struct RewriteTab: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 14) {
            // Mode Selection Card
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr(ru: "Режим замены на месте", en: "In-place Replacement Mode"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.tr(ru: "Выберите, как модель обрабатывает выделенный текст по горячим клавишам:", en: "Choose how the model processes text selected in any app:"))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }

                // Interactive Mode Cards
                HStack(spacing: 12) {
                    modeSelectionCard(
                        mode: .proofread,
                        icon: "checkmark.shield.fill",
                        gradient: [Color(red: 0.15, green: 0.78, blue: 0.55), Color(red: 0.08, green: 0.58, blue: 0.42)]
                    )

                    modeSelectionCard(
                        mode: .improveStyle,
                        icon: "sparkles",
                        gradient: [Color(red: 0.62, green: 0.38, blue: 0.98), Color(red: 0.44, green: 0.22, blue: 0.88)]
                    )
                }

                Divider()

                // What changes section
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr(ru: "Что меняется при переключении:", en: "What changes between modes:"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(spacing: 7) {
                        modeComparisonRow(
                            label: L10n.tr(ru: "Слова и формулировки:", en: "Words & phrasing:"),
                            value: settings.rewriteMode.wordingBehavior,
                            icon: "textformat.abc"
                        )

                        modeComparisonRow(
                            label: L10n.tr(ru: "Температура модели:", en: "AI temperature:"),
                            value: settings.rewriteMode.temperatureDescription,
                            icon: "thermometer.medium"
                        )

                        modeComparisonRow(
                            label: L10n.tr(ru: "Назначение:", en: "Recommended for:"),
                            value: settings.rewriteMode.recommendedFor,
                            icon: "target"
                        )
                    }

                    // Live Example Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            Text(L10n.tr(
                                ru: "Наглядный пример работы (\(settings.rewriteMode.title)):",
                                en: "Transformation example (\(settings.rewriteMode.title)):"
                            ))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 6) {
                                Text(L10n.tr(ru: "Было:", en: "Before:"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 44, alignment: .leading)
                                Text("«\(settings.rewriteMode.exampleOriginal)»")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            HStack(alignment: .top, spacing: 6) {
                                Text(L10n.tr(ru: "Стало:", en: "After:"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 44, alignment: .leading)
                                Text("«\(settings.rewriteMode.exampleResult)»")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)

            // Shortcuts & Protection Card
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr(ru: "Горячие клавиши замены", en: "In-place Replacement Shortcuts"))
                    .font(.system(size: 13, weight: .semibold))

                ShortcutRecorderView(
                    label: L10n.tr(ru: "Замена выделенного фрагмента:", en: "Replace selected text:"),
                    shortcut: $settings.rewriteShortcut,
                    defaultShortcut: ShortcutModel.defaultRewrite
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                        Text(L10n.tr(ru: "Безопасность и защита текста", en: "Safety & Text Protection"))
                            .font(.system(size: 12, weight: .medium))
                    }

                    Text(L10n.tr(
                        ru: "При ошибке сети или API оригинальный текст в поле ввода не стирается, а иконка в строке меню мягко моргает красным цветом.",
                        en: "If a network or API error occurs, original text in the input field is never erased, and the menu bar icon gently blinks red."
                    ))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
    }

    private func modeSelectionCard(mode: RewriteMode, icon: String, gradient: [Color]) -> some View {
        let isSelected = settings.rewriteMode == mode
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                settings.rewriteMode = mode
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)

                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text(mode.shortBadge)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                        )
                        .foregroundColor(isSelected ? .accentColor : .secondary)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .accentColor : Color.secondary.opacity(0.4))
                }

                Text(mode.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(mode.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeComparisonRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Tab 4: Permissions Content

struct PermissionsTab: View {
    @State private var isAxGranted = TextCaptureService.isAccessibilityGranted()
    @State private var isChecking = false
    @State private var feedbackText: String? = nil
    @State private var feedbackIsSuccess = true
    @State private var feedbackResetTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((isAxGranted ? Color.green : Color.orange).opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: isAxGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isAxGranted ? .green : .orange)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isAxGranted
                            ? L10n.tr(ru: "Универсальный доступ разрешен", en: "Accessibility Granted")
                            : L10n.tr(ru: "Требуется Универсальный доступ", en: "Accessibility Required"))
                            .font(.system(size: 14, weight: .semibold))
                        Text(isAxGranted
                            ? L10n.tr(ru: "LightL имеет права для чтения и вставки текста в любых приложениях macOS.", en: "LightL has permission to read and insert text across macOS apps.")
                            : L10n.tr(ru: "Необходимо разрешить LightL в Системных настройках для работы горячих клавиш и замены текста.", en: "Enable LightL in System Settings for shortcuts and in-place replacement to function."))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: checkAccessibilityStatus) {
                        HStack(spacing: 6) {
                            if isChecking {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                                Text(L10n.tr(ru: "Проверка...", en: "Checking..."))
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(L10n.tr(ru: "Проверить статус", en: "Check Status"))
                            }
                        }
                    }
                    .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: false))
                    .disabled(isChecking)

                    Button(L10n.tr(ru: "Открыть Системные настройки", en: "Open System Settings")) {
                        TextCaptureService.openAccessibilitySettings()
                    }
                    .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: true))

                    if let text = feedbackText {
                        HStack(spacing: 5) {
                            Image(systemName: feedbackIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(text)
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundColor(feedbackIsSuccess ? .green : .orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill((feedbackIsSuccess ? Color.green : Color.orange).opacity(0.12))
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }

                if !isAxGranted {
                    Text(L10n.tr(
                        ru: "Если macOS не показала системный запрос, нажмите «Открыть Системные настройки» и включите тумблер LightL вручную.",
                        en: "If macOS didn't show a system prompt, click \"Open System Settings\" and enable the LightL toggle manually."
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
        .onAppear {
            isAxGranted = TextCaptureService.isAccessibilityGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            let granted = TextCaptureService.isAccessibilityGranted()
            isAxGranted = granted
            if granted {
                HotKeyManager.shared.recheckDoubleCmdCMonitor()
            }
        }
    }

    private func checkAccessibilityStatus() {
        feedbackResetTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            isChecking = true
            feedbackText = nil
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)

            let granted = TextCaptureService.isAccessibilityGranted(prompt: !isAxGranted)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isAxGranted = granted
                self.isChecking = false
                if granted {
                    HotKeyManager.shared.recheckDoubleCmdCMonitor()
                    self.feedbackIsSuccess = true
                    self.feedbackText = L10n.tr(
                        ru: "Права активны",
                        en: "Permission active"
                    )
                } else {
                    self.feedbackIsSuccess = false
                    self.feedbackText = L10n.tr(
                        ru: "Доступ не включен",
                        en: "Not yet enabled"
                    )
                }
            }

            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

            feedbackResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.feedbackText = nil
                    }
                }
            }
        }
    }
}

// MARK: - Tab 5: Appearance Content (macOS 27 HIG Standards)

struct AppearanceTab: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 14) {
            // Language Selection Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                        .foregroundColor(.accentColor)
                    Text(L10n.tr(ru: "Язык интерфейса", en: "Interface Language"))
                        .font(.system(size: 13, weight: .semibold))
                }

                Picker(L10n.tr(ru: "Язык:", en: "Language:"), selection: $settings.interfaceLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text(L10n.tr(
                    ru: "По умолчанию используется системный язык macOS.",
                    en: "By default, matches your macOS system language."
                ))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "macwindow.and.cursor")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr(ru: "Стиль интерфейса", en: "UI Style"))
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.tr(
                            ru: "Liquid Glass с динамическим линзированием и структурированными карточками.",
                            en: "Liquid Glass with dynamic lensing and structured content cards."
                        ))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr(ru: "Принципы дизайна:", en: "Design Principles:"))
                        .font(.system(size: 12, weight: .semibold))

                    bulletPoint(
                        title: L10n.tr(ru: "Навигация на жидком стекле (Liquid Glass):", en: "Liquid Glass Navigation:"),
                        detail: L10n.tr(
                            ru: "Боковые панели, всплывающие окна и кнопки используют полупрозрачный мета-материал с градиентным бликом верхней кромки.",
                            en: "Sidebars, popovers, and buttons use translucent material with specular top-edge highlights."
                        )
                    )

                    bulletPoint(
                        title: L10n.tr(ru: "Золотое правило читаемости контента:", en: "Content Readability Rule:"),
                        detail: L10n.tr(
                            ru: "Текст перевода и поля ввода размещаются на плотных структурированных карточках с контрастными границами для 100% читаемости на любых обоях.",
                            en: "Translations and inputs reside on solid structured cards with contrast borders for 100% legibility on any wallpaper."
                        )
                    )

                    bulletPoint(
                        title: L10n.tr(ru: "Цветные значки боковой панели:", en: "Colored Sidebar Icons:"),
                        detail: L10n.tr(
                            ru: "Возвращение акцентных цветных иконок для быстрого сканирования разделов.",
                            en: "Vibrant colored SF Symbols for rapid visual section recognition."
                        )
                    )

                    bulletPoint(
                        title: L10n.tr(ru: "Поддержка системного слайдера прозрачности:", en: "System Transparency Slider Support:"),
                        detail: L10n.tr(
                            ru: "Интерфейс корректно реагирует на ползунок Liquid Glass в Системных настройках macOS и режим «Уменьшение прозрачности».",
                            en: "Responds seamlessly to system Liquid Glass opacity sliders and Reduce Transparency mode."
                        )
                    )
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
    }

    private func bulletPoint(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.primary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
