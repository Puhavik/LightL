import Foundation
import AppKit

@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var activeAnimationTask: Task<Void, Never>?
    private var settingsObserver: (any NSObjectProtocol)?
    public private(set) var isMenuVisible = false

    private let errorIconName = "exclamationmark.triangle.fill"
    private let loadingIconName = "arrow.triangle.2.circlepath"

    public static var appVersion: String {
        let raw = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
            ?? "dev"
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "dev" }
        return (trimmed == "dev" || trimmed.hasPrefix("v")) ? trimmed : "v\(trimmed)"
    }

    public static let defaultMenuBarIcon: NSImage = {
        if let img = Bundle.main.image(forResource: "MenuBarIcon") {
            img.isTemplate = true
            return img
        }
        if let resourceUrl = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: resourceUrl) {
            img.isTemplate = true
            return img
        }
        // Bundle.module traps if the SwiftPM resource bundle cannot be opened (e.g. flat bundle built on CI),
        // so only touch it outside a packaged .app (swift run / swift test).
        #if SWIFT_PACKAGE
        if Bundle.main.bundleURL.pathExtension != "app", let img = Bundle.module.image(forResource: "MenuBarIcon") {
            img.isTemplate = true
            return img
        }
        #endif
        return drawVectorMenuBarIcon()
    }()

    public static func drawVectorMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
            context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            context.setLineWidth(2.0)
            let lPath = CGMutablePath()
            lPath.move(to: CGPoint(x: 4.2, y: 3.8))
            lPath.addLine(to: CGPoint(x: 4.2, y: 14.2))
            lPath.addLine(to: CGPoint(x: 9.8, y: 14.2))
            context.addPath(lPath)
            context.strokePath()
            
            let center = CGPoint(x: 12.8, y: 6.8)
            let r: CGFloat = 3.8
            let p = r * 0.16
            let sparkPath = CGMutablePath()
            sparkPath.move(to: CGPoint(x: center.x, y: center.y - r))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y), control: CGPoint(x: center.x + p, y: center.y - p))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r), control: CGPoint(x: center.x + p, y: center.y + p))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y), control: CGPoint(x: center.x - p, y: center.y + p))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r), control: CGPoint(x: center.x - p, y: center.y - p))
            sparkPath.closeSubpath()
            context.addPath(sparkPath)
            context.fillPath()
            
            return true
        }
        img.isTemplate = true
        return img
    }

    private var normalIcon: NSImage {
        Self.defaultMenuBarIcon
    }

    public var onOpenSettings: (() -> Void)?

    public override init() {
        super.init()
        setupStatusItem()
        observeSettings()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = normalIcon
            button.imagePosition = .imageOnly
            button.toolTip = L10n.tr(ru: "LightL — AI переводчик и редактор", en: "LightL — AI Translator & Editor")
        }
        rebuildMenu()
    }

    private func observeSettings() {
        if let existing = settingsObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: AppSettings.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isMenuVisible else { return }
                self.rebuildMenu()
            }
        }
    }

    public func destroy() {
        stopBlinking()
        if let obs = settingsObserver {
            NotificationCenter.default.removeObserver(obs)
            settingsObserver = nil
        }
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    public func rebuildMenu() {
        guard !isMenuVisible else { return }
        let menu = statusItem?.menu ?? NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        populateMenu(menu)
        statusItem?.menu = menu
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        populateMenu(menu)
    }

    public func menuWillOpen(_ menu: NSMenu) {
        isMenuVisible = true
    }

    public func menuDidClose(_ menu: NSMenu) {
        isMenuVisible = false
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // Title item with version in top-right corner
        let titleItem = NSMenuItem(title: "LightL AI", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        if let font = NSFont.boldSystemFont(ofSize: 12) as NSFont? {
            titleItem.attributedTitle = NSAttributedString(
                string: "LightL AI",
                attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
            )
        }
        titleItem.badge = NSMenuItemBadge(string: Self.appVersion)
        titleItem.toolTip = L10n.tr(ru: "Версия LightL: \(Self.appVersion)", en: "LightL Version: \(Self.appVersion)")
        menu.addItem(titleItem)

        // API Status indicator
        let hasKey = !AppSettings.shared.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let apiStatusItem = NSMenuItem(
            title: hasKey
                ? L10n.tr(ru: "● API Gemini: Настроен", en: "● Gemini API: Ready")
                : L10n.tr(ru: "○ API Gemini: Введите ключ", en: "○ Gemini API: Enter Key"),
            action: #selector(menuOpenSettings),
            keyEquivalent: ""
        )
        apiStatusItem.target = self
        menu.addItem(apiStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Target language submenu
        let langMenu = NSMenu()
        let currentLang = AppSettings.shared.targetLanguageCode
        for lang in LanguageModel.supportedLanguages {
            let item = NSMenuItem(title: "\(lang.localizedName) (\(lang.nativeName))", action: #selector(changeLanguageAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.code
            item.state = (lang.code == currentLang) ? .on : .off
            langMenu.addItem(item)
        }
        let targetLangItem = NSMenuItem(
            title: L10n.tr(
                ru: "Язык перевода: \(AppSettings.shared.targetLanguage.localizedName)",
                en: "Translation: \(AppSettings.shared.targetLanguage.localizedName)"
            ),
            action: nil,
            keyEquivalent: ""
        )
        targetLangItem.submenu = langMenu
        menu.addItem(targetLangItem)

        // Rewrite mode submenu
        let modeMenu = NSMenu()
        let currentMode = AppSettings.shared.rewriteMode
        for mode in RewriteMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(changeModeAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = (mode == currentMode) ? .on : .off
            modeMenu.addItem(item)
        }
        let modeItem = NSMenuItem(
            title: L10n.tr(
                ru: "Режим замены: \(currentMode.title)",
                en: "Replacement: \(currentMode.title)"
            ),
            action: nil,
            keyEquivalent: ""
        )
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        menu.addItem(NSMenuItem.separator())

        // Accessibility status (shown ONLY when access is NOT granted)
        let isAxGranted = TextCaptureService.isAccessibilityGranted(prompt: false)
        if !isAxGranted {
            let axItem = NSMenuItem(
                title: L10n.tr(ru: "⚠ Требуется Универсальный доступ", en: "⚠ Accessibility Required"),
                action: #selector(openAccessibilityAction),
                keyEquivalent: ""
            )
            axItem.target = self
            menu.addItem(axItem)
        }

        // Settings
        let settingsItem = NSMenuItem(
            title: L10n.tr(ru: "Настройки...", en: "Settings..."),
            action: #selector(menuOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let loginItem = NSMenuItem(
            title: L10n.tr(ru: "Запускать при входе в систему", en: "Launch at Login"),
            action: #selector(toggleLaunchAtLoginAction),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : (LaunchAtLogin.needsApproval ? .mixed : .off)
        if LaunchAtLogin.needsApproval {
            loginItem.toolTip = L10n.tr(ru: "Требуется подтверждение в Системных настройках → Объекты входа", en: "Needs approval in System Settings → Login Items")
        }
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: L10n.tr(ru: "Завершить LightL", en: "Quit LightL"),
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Status Visual States

    public func setLoading(_ loading: Bool) {
        guard let button = statusItem?.button else { return }
        stopBlinking()
        if loading {
            let img = NSImage(
                systemSymbolName: loadingIconName,
                accessibilityDescription: L10n.tr(ru: "Загрузка...", en: "Loading...")
            )
            button.image = img
            button.contentTintColor = NSColor.systemBlue
        } else {
            resetNormalIcon()
        }
    }

    /// Triggers the blinking error animation in the Menu Bar icon
    public func triggerErrorBlink(message: String) {
        guard let button = statusItem?.button else { return }
        stopActiveAnimation()

        button.toolTip = L10n.tr(ru: "Ошибка: \(message)", en: "Error: \(message)")

        activeAnimationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let maxBlinks = 6
            for i in 0..<maxBlinks {
                if Task.isCancelled { break }
                let isErrorState = (i % 2 == 0)
                if isErrorState {
                    button.image = NSImage(
                        systemSymbolName: self.errorIconName,
                        accessibilityDescription: L10n.tr(ru: "Ошибка", en: "Error")
                    )
                    button.contentTintColor = NSColor.systemRed
                } else {
                    button.image = self.normalIcon
                    button.contentTintColor = nil
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            guard !Task.isCancelled else { return }
            self.resetNormalIcon()
        }
    }

    public func triggerSuccessFlash() {
        guard let button = statusItem?.button else { return }
        stopActiveAnimation()
        button.contentTintColor = NSColor.systemGreen
        activeAnimationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.resetNormalIcon()
        }
    }

    private func resetNormalIcon() {
        guard let button = statusItem?.button else { return }
        button.image = normalIcon
        button.contentTintColor = nil
        button.toolTip = L10n.tr(ru: "LightL — AI переводчик и редактор", en: "LightL — AI Translator & Editor")
    }

    private func stopBlinking() {
        stopActiveAnimation()
    }

    private func stopActiveAnimation() {
        activeAnimationTask?.cancel()
        activeAnimationTask = nil
        resetNormalIcon()
    }

    // MARK: - Actions

    @objc private func menuOpenSettings() {
        onOpenSettings?()
    }

    @objc private func toggleLaunchAtLoginAction() {
        if LaunchAtLogin.needsApproval {
            LaunchAtLogin.openSystemSettings()
        } else {
            LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        }
    }

    @objc private func changeLanguageAction(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String {
            AppSettings.shared.targetLanguageCode = code
        }
    }

    @objc private func changeModeAction(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? RewriteMode {
            AppSettings.shared.rewriteMode = mode
        }
    }

    @objc private func openAccessibilityAction() {
        _ = TextCaptureService.isAccessibilityGranted(prompt: true)
        TextCaptureService.openAccessibilitySettings()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
