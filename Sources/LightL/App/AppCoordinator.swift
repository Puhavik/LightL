import Foundation
import AppKit

@MainActor
final class StreamGate {
    static let minInterval: TimeInterval = 0.05
    var finished = false
    private var lastRender: TimeInterval?

    func shouldRender(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard !finished else { return false }
        if let last = lastRender, now - last < Self.minInterval, now >= last { return false }
        lastRender = now
        return true
    }
}

struct AmbiguousRewriteGate {
    static let window: TimeInterval = 5
    private var pending: (text: String, at: TimeInterval)?

    mutating func confirm(text: String, at now: TimeInterval) -> Bool {
        if let pending, pending.text == text, now >= pending.at, now - pending.at < Self.window {
            self.pending = nil
            return true
        }
        pending = (text, now)
        return false
    }
}

@MainActor
public final class AppCoordinator {
    public static let shared = AppCoordinator()

    private let settings: AppSettings
    private let textCapture: any TextCapturing
    private let gemini: any TextTransforming
    private let hotKeyManager = HotKeyManager.shared

    private var statusBarController: (any StatusIndicating)!
    private var translationPanel: (any TranslationPresenting)!

    internal var currentTranslateTask: Task<Void, Never>?
    private var currentTranslateTaskId = UUID()
    internal var currentRewriteTask: Task<Void, Never>?
    private var currentRewriteTaskId = UUID()
    private var currentReplaceTask: Task<Void, Never>?
    private var ambiguousRewriteGate = AmbiguousRewriteGate()
    private var settingsObserver: (any NSObjectProtocol)?

    private init() {
        settings = AppSettings.shared
        textCapture = TextCaptureService.shared
        gemini = GeminiService.shared
    }

    internal init(
        settings: AppSettings,
        textCapture: any TextCapturing,
        gemini: any TextTransforming,
        statusBar: any StatusIndicating,
        panel: any TranslationPresenting
    ) {
        self.settings = settings
        self.textCapture = textCapture
        self.gemini = gemini
        self.statusBarController = statusBar
        self.translationPanel = panel
        installDismissHandler()
    }

    private func installDismissHandler() {
        translationPanel.onDismiss = { [weak self] in
            guard let self = self else { return }
            self.currentTranslateTaskId = UUID()
            self.currentTranslateTask?.cancel()
            self.currentTranslateTask = nil
            self.statusBarController.setLoading(false)
        }
    }

    public func start() {
        if !settings.geminiApiKey.isEmpty {
            Task {
                await gemini.prewarm()
            }
        }

        let realStatusBar = StatusBarController()
        realStatusBar.onOpenSettings = {
            SettingsWindowController.shared.show()
        }
        statusBarController = realStatusBar

        translationPanel = FloatingTranslationPanel()
        installDismissHandler()

        setupHotKeyCallbacks()
        applyCurrentHotKeys()
        observeSettingsChanges()

        // Check accessibility
        if !TextCaptureService.isAccessibilityGranted(prompt: false) {
            print("[LightL] Accessibility permissions not yet granted.")
        }
    }

    public func stop() {
        translationPanel?.dismiss()
        currentTranslateTask?.cancel()
        currentTranslateTask = nil
        currentRewriteTask?.cancel()
        currentRewriteTask = nil
        currentReplaceTask?.cancel()
        currentReplaceTask = nil
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
        }
        hotKeyManager.unregisterHotKeys()
        statusBarController?.destroy()
    }

    private func setupHotKeyCallbacks() {
        hotKeyManager.onTranslate = { [weak self] in
            self?.handleTranslateTrigger()
        }

        hotKeyManager.onRewrite = { [weak self] in
            self?.handleRewriteTrigger()
        }
    }

    private var appliedHotKeyState: (ShortcutModel, ShortcutModel)?
    private var appliedDoubleCmdC: Bool?

    private func applyCurrentHotKeys() {
        let state = (settings.translateShortcut, settings.rewriteShortcut)
        if let applied = appliedHotKeyState, applied == state {
            if appliedDoubleCmdC != settings.doubleCmdCEnabled {
                appliedDoubleCmdC = settings.doubleCmdCEnabled
                hotKeyManager.recheckDoubleCmdCMonitor()
            }
            return
        }
        appliedHotKeyState = state
        appliedDoubleCmdC = settings.doubleCmdCEnabled
        let (translateSuccess, rewriteSuccess) = hotKeyManager.updateHotKeys(
            translateShortcut: settings.translateShortcut,
            rewriteShortcut: settings.rewriteShortcut,
            enableDoubleCmdC: settings.doubleCmdCEnabled
        )
        if !translateSuccess {
            print("[LightL] Failed to register translate shortcut: \(settings.translateShortcut.displayString)")
        }
        if !rewriteSuccess {
            print("[LightL] Failed to register rewrite shortcut: \(settings.rewriteShortcut.displayString)")
        }
        let failed = [
            translateSuccess ? nil : settings.translateShortcut.displayString,
            rewriteSuccess ? nil : settings.rewriteShortcut.displayString
        ].compactMap { $0 }
        if !failed.isEmpty {
            let list = failed.joined(separator: ", ")
            statusBarController?.triggerErrorBlink(
                message: L10n.tr(ru: "Сочетание недоступно или занято: \(list)", en: "Shortcut unavailable or already in use: \(list)")
            )
        }
    }

    private func observeSettingsChanges() {
        if let existing = settingsObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: AppSettings.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyCurrentHotKeys()
            }
        }
    }

    // MARK: - Scenario 1: Translation (Floating Popover)

    private func copyAction(_ text: String) -> () -> Void {
        {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }

    private func replaceAction(_ text: String, selection: CapturedSelection) -> () -> Void {
        { [weak self] in
            guard let self = self else { return }
            self.translationPanel.dismiss()
            if let targetPID = selection.frontmostAppPID,
               let currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
               targetPID != currentPID {
                self.statusBarController.triggerErrorBlink(
                    message: L10n.tr(ru: "Активное окно изменилось во время обработки", en: "Active window changed during processing")
                )
                return
            }
            self.currentReplaceTask?.cancel()
            self.currentReplaceTask = Task { [weak self] in
                if await self?.textCapture.replaceSelection(with: text, verifying: selection) == false {
                    self?.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Выделение изменилось, замена отменена", en: "Selection changed, replacement cancelled")
                    )
                }
            }
        }
    }

    internal func handleTranslateTrigger() {
        currentRewriteTask?.cancel()
        currentRewriteTask = nil

        guard TextCaptureService.isAccessibilityGranted(prompt: false) else {
            statusBarController.triggerErrorBlink(
                message: L10n.tr(ru: "Требуется Универсальный доступ", en: "Accessibility permission required")
            )
            SettingsWindowController.shared.show()
            return
        }

        let taskId = UUID()
        currentTranslateTaskId = taskId
        currentTranslateTask?.cancel()
        currentTranslateTask = Task { [weak self] in
            guard let self = self else { return }

            guard let selection = await self.textCapture.captureSelection(),
                  !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if !Task.isCancelled && self.currentTranslateTaskId == taskId {
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Выделите текст для перевода", en: "Select text to translate")
                    )
                }
                return
            }

            guard !Task.isCancelled && self.currentTranslateTaskId == taskId else { return }

            let targetLanguage = self.settings.targetLanguage
            let originalText = selection.text
            let apiKey = self.settings.geminiApiKey
            let modelId = self.settings.selectedModelId
            let gate = StreamGate()
            defer { gate.finished = true }

            let location: FloatingTranslationPanel.EitherPointOrRect
            if let bounds = selection.bounds {
                location = .rect(bounds)
            } else {
                location = .point(selection.mouseLocation)
            }

            self.translationPanel.canReplace = !selection.isAmbiguousLineCopy

            // Show floating panel in loading state
            self.translationPanel.show(
                originalText: originalText,
                targetLanguage: targetLanguage,
                near: location,
                onCopy: {},
                onReplace: {}
            )

            self.statusBarController.setLoading(true)

            do {
                let translated = try await self.gemini.translate(
                    text: originalText,
                    targetLanguage: targetLanguage,
                    apiKey: apiKey,
                    model: modelId,
                    onChunk: { [weak self] partialText in
                        Task { @MainActor [weak self] in
                            guard let self = self, self.currentTranslateTaskId == taskId, !Task.isCancelled, gate.shouldRender() else { return }
                            self.translationPanel.updateTranslation(
                                originalText: originalText,
                                translatedText: partialText,
                                targetLanguage: targetLanguage,
                                isStreaming: true,
                                onCopy: self.copyAction(partialText),
                                onReplace: self.replaceAction(partialText, selection: selection)
                            )
                        }
                    }
                )

                guard !Task.isCancelled && self.currentTranslateTaskId == taskId else {
                    if self.currentTranslateTaskId == taskId { self.statusBarController.setLoading(false) }
                    return
                }

                self.statusBarController.setLoading(false)

                self.translationPanel.updateTranslation(
                    originalText: originalText,
                    translatedText: translated,
                    targetLanguage: targetLanguage,
                    isStreaming: false,
                    onCopy: self.copyAction(translated),
                    onReplace: self.replaceAction(translated, selection: selection)
                )
            } catch {
                guard !Task.isCancelled && self.currentTranslateTaskId == taskId else {
                    if self.currentTranslateTaskId == taskId { self.statusBarController.setLoading(false) }
                    return
                }
                self.statusBarController.setLoading(false)
                self.statusBarController.triggerErrorBlink(message: error.localizedDescription)
                self.translationPanel.showError(
                    originalText: originalText,
                    error: error.localizedDescription,
                    targetLanguage: targetLanguage,
                    onCopy: {},
                    onReplace: {}
                )
            }
        }
    }

    // MARK: - Scenario 2: In-place Proofreading / Rewrite

    internal func handleRewriteTrigger() {
        currentTranslateTaskId = UUID()
        currentTranslateTask?.cancel()
        currentTranslateTask = nil
        translationPanel?.dismiss()

        guard TextCaptureService.isAccessibilityGranted(prompt: false) else {
            statusBarController.triggerErrorBlink(
                message: L10n.tr(ru: "Требуется Универсальный доступ", en: "Accessibility permission required")
            )
            return
        }

        let taskId = UUID()
        currentRewriteTaskId = taskId
        currentRewriteTask?.cancel()
        currentRewriteTask = Task { [weak self] in
            guard let self = self else { return }

            guard let captured = await self.textCapture.captureSelection(),
                  !captured.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if !Task.isCancelled && self.currentRewriteTaskId == taskId {
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Выделите текст для исправления", en: "Select text to improve")
                    )
                }
                return
            }

            guard !Task.isCancelled && self.currentRewriteTaskId == taskId else { return }

            var selection = captured
            var copyOnly = false
            if captured.isAmbiguousLineCopy {
                if self.ambiguousRewriteGate.confirm(text: captured.text, at: ProcessInfo.processInfo.systemUptime) {
                    selection = captured.confirmingLineCopy()
                    copyOnly = true
                } else {
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(
                            ru: "Скопирована целая строка. Нажмите ещё раз в течение 5 с, чтобы получить результат в буфере обмена, или выделите текст без переноса строки",
                            en: "Whole line copied. Press again within 5 s to get the result on the clipboard, or select the text without the line break"
                        )
                    )
                    return
                }
            }

            let originalText = selection.text
            let mode = self.settings.rewriteMode
            let apiKey = self.settings.geminiApiKey
            let modelId = self.settings.selectedModelId
            let targetPID = selection.frontmostAppPID

            self.statusBarController.setLoading(true)

            do {
                let corrected = try await self.gemini.rewrite(
                    text: originalText,
                    mode: mode,
                    apiKey: apiKey,
                    model: modelId
                )

                guard !Task.isCancelled && self.currentRewriteTaskId == taskId else {
                    guard self.currentRewriteTaskId == taskId else { return }
                    self.statusBarController.setLoading(false)
                    return
                }

                // Verify frontmost application hasn't changed to avoid pasting into wrong app
                if let targetPID = targetPID,
                   let currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
                   targetPID != currentPID {
                    guard self.currentRewriteTaskId == taskId else { return }
                    self.statusBarController.setLoading(false)
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Активное окно изменилось во время обработки", en: "Active window changed during processing")
                    )
                    return
                }

                guard self.currentRewriteTaskId == taskId else { return }
                self.statusBarController.setLoading(false)

                if copyOnly {
                    // The capture may not be a real selection, so never paste into the document: hand the result over via the clipboard.
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([TextCaptureService.makeTransientItem(text: corrected)])
                    self.statusBarController.triggerSuccessFlash()
                    return
                }

                // Replace selected text in active app
                let success = await self.textCapture.replaceSelection(with: corrected, verifying: selection)
                guard self.currentRewriteTaskId == taskId else { return }
                if success {
                    self.statusBarController.triggerSuccessFlash()
                } else {
                    // Original text is preserved untouched
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Не удалось вставить исправленный текст", en: "Failed to paste corrected text")
                    )
                }
            } catch {
                guard !Task.isCancelled && self.currentRewriteTaskId == taskId else {
                    guard self.currentRewriteTaskId == taskId else { return }
                    self.statusBarController.setLoading(false)
                    return
                }
                // If anything fails, original text remains untouched in active app!
                guard self.currentRewriteTaskId == taskId else { return }
                self.statusBarController.setLoading(false)
                self.statusBarController.triggerErrorBlink(message: error.localizedDescription)
            }
        }
    }
}
