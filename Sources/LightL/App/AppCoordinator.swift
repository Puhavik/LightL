import Foundation
import AppKit

@MainActor
public final class AppCoordinator {
    public static let shared = AppCoordinator()

    private let settings = AppSettings.shared
    private let textCapture = TextCaptureService.shared
    private let gemini = GeminiService.shared
    private let hotKeyManager = HotKeyManager.shared

    private var statusBarController: StatusBarController!
    private var translationPanel: FloatingTranslationPanel!

    private var currentTranslateTask: Task<Void, Never>?
    private var currentRewriteTask: Task<Void, Never>?
    private var currentReplaceTask: Task<Void, Never>?

    private init() {}

    public func start() {
        Task {
            await gemini.prewarm()
        }

        statusBarController = StatusBarController()
        statusBarController.onOpenSettings = {
            SettingsWindowController.shared.show()
        }

        translationPanel = FloatingTranslationPanel()

        setupHotKeyCallbacks()
        applyCurrentHotKeys()
        observeSettingsChanges()

        // Check accessibility
        if !TextCaptureService.isAccessibilityGranted(prompt: false) {
            print("[LightL] Accessibility permissions not yet granted.")
        }
    }

    public func stop() {
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

    private func applyCurrentHotKeys() {
        hotKeyManager.updateHotKeys(
            translateShortcut: settings.translateShortcut,
            rewriteShortcut: settings.rewriteShortcut,
            enableDoubleCmdC: settings.doubleCmdCEnabled
        )
    }

    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
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

    private func handleTranslateTrigger() {
        currentTranslateTask?.cancel()
        currentTranslateTask = Task { [weak self] in
            guard let self = self else { return }

            guard let selection = await self.textCapture.captureSelection(),
                  !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if !Task.isCancelled {
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Выделите текст для перевода", en: "Select text to translate")
                    )
                }
                return
            }

            guard !Task.isCancelled else { return }

            let targetLanguage = self.settings.targetLanguage
            let originalText = selection.text
            let apiKey = self.settings.geminiApiKey
            let modelId = self.settings.selectedModelId

            let location: FloatingTranslationPanel.EitherPointOrRect
            if let bounds = selection.bounds {
                location = .rect(bounds)
            } else {
                location = .point(selection.mouseLocation)
            }

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
                            guard let self = self, !Task.isCancelled else { return }
                            self.statusBarController.setLoading(false)
                            self.translationPanel.updateTranslation(
                                originalText: originalText,
                                translatedText: partialText,
                                targetLanguage: targetLanguage,
                                onCopy: {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.setString(partialText, forType: .string)
                                },
                                onReplace: { [weak self] in
                                    guard let self = self else { return }
                                    self.currentReplaceTask?.cancel()
                                    self.currentReplaceTask = Task { [weak self] in
                                        _ = await self?.textCapture.replaceSelection(with: partialText)
                                    }
                                }
                            )
                        }
                    }
                )

                guard !Task.isCancelled else {
                    self.statusBarController.setLoading(false)
                    return
                }

                self.statusBarController.setLoading(false)

                self.translationPanel.updateTranslation(
                    originalText: originalText,
                    translatedText: translated,
                    targetLanguage: targetLanguage,
                    onCopy: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(translated, forType: .string)
                    },
                    onReplace: { [weak self] in
                        guard let self = self else { return }
                        self.currentReplaceTask?.cancel()
                        self.currentReplaceTask = Task { [weak self] in
                            _ = await self?.textCapture.replaceSelection(with: translated)
                        }
                    }
                )
            } catch {
                guard !Task.isCancelled else {
                    self.statusBarController.setLoading(false)
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

    private func handleRewriteTrigger() {
        currentRewriteTask?.cancel()
        currentRewriteTask = Task { [weak self] in
            guard let self = self else { return }

            guard let selection = await self.textCapture.captureSelection(),
                  !selection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if !Task.isCancelled {
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Выделите текст для исправления", en: "Select text to improve")
                    )
                }
                return
            }

            guard !Task.isCancelled else { return }

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

                guard !Task.isCancelled else {
                    self.statusBarController.setLoading(false)
                    return
                }

                // Verify frontmost application hasn't changed to avoid pasting into wrong app
                if let targetPID = targetPID,
                   let currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
                   targetPID != currentPID {
                    self.statusBarController.setLoading(false)
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Активное окно изменилось во время обработки", en: "Active window changed during processing")
                    )
                    return
                }

                self.statusBarController.setLoading(false)

                // Replace selected text in active app
                let success = await self.textCapture.replaceSelection(with: corrected)
                if success {
                    self.statusBarController.triggerSuccessFlash()
                } else {
                    // Original text is preserved untouched
                    self.statusBarController.triggerErrorBlink(
                        message: L10n.tr(ru: "Не удалось вставить исправленный текст", en: "Failed to paste corrected text")
                    )
                }
            } catch {
                guard !Task.isCancelled else {
                    self.statusBarController.setLoading(false)
                    return
                }
                // If anything fails, original text remains untouched in active app!
                self.statusBarController.setLoading(false)
                self.statusBarController.triggerErrorBlink(message: error.localizedDescription)
            }
        }
    }
}
