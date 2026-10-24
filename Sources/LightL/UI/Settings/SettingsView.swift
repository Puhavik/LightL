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
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            .frame(height: 28)

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

            LaunchAtLoginToggle()
                .padding(.horizontal, 14)

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

struct LaunchAtLoginToggle: View {
    @State private var launchAtLogin = LaunchAtLogin.isRequested

    var body: some View {
        Toggle(L10n.tr(ru: "Запускать при входе", en: "Launch at Login"), isOn: $launchAtLogin)
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            .help(LaunchAtLogin.needsApproval
                ? L10n.tr(ru: "Подтвердите в Системных настройках → Основные → Объекты входа.", en: "Approve in System Settings → General → Login Items.")
                : L10n.tr(ru: "По умолчанию выключено. Также доступно в Системных настройках → Объекты входа.", en: "Off by default. Also manageable in System Settings → Login Items."))
            .onChange(of: launchAtLogin) { _, on in
                LaunchAtLogin.setEnabled(on)
                launchAtLogin = LaunchAtLogin.isRequested
            }
            .onAppear { launchAtLogin = LaunchAtLogin.isRequested }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                launchAtLogin = LaunchAtLogin.isRequested
            }
    }
}
