import Testing
import SwiftUI
import AppKit
@testable import LightL

@Suite("Screenshot Generation")
struct ScreenshotGenerator {

    @MainActor
    private func renderViewInWindow<V: View>(view: V, size: CGSize, isOpaque: Bool = false) -> NSImage? {
        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = isOpaque
        win.backgroundColor = isOpaque ? .windowBackgroundColor : .clear

        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        win.contentView = hosting
        win.layoutIfNeeded()
        win.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return nil
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    @MainActor
    private func saveImage(_ image: NSImage, to path: String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        try? pngData.write(to: URL(fileURLWithPath: path))
    }

    @Test("Generate README Screenshots")
    @MainActor
    func generateScreenshots() {
        let assetsDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        let originalKey = AppSettings.shared.geminiApiKey
        AppSettings.shared.geminiApiKey = "AIzaSyB-demo-key-connected"
        defer {
            AppSettings.shared.geminiApiKey = originalKey
        }

        let targetLangRu = LanguageModel.supportedLanguages.first(where: { $0.code == "ru" }) ?? LanguageModel.defaultTarget

        let sampleEnglish = "The quick brown fox jumps over the lazy dog. Swift 6 brings data race safety by default."
        let sampleRussian = "Быстрая коричневая лисица перепрыгивает через ленивую собаку. Swift 6 обеспечивает безопасность от гонок данных по умолчанию."

        // 1. Popover Dark
        let popoverDark = ZStack {
            TranslationContentView(
                originalText: sampleEnglish,
                translatedText: sampleRussian,
                isLoading: false,
                isStreaming: false,
                errorMessage: nil,
                targetLanguage: targetLangRu,
                onCopy: {},
                onReplace: {},
                onClose: {}
            )
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .frame(width: 420, height: 260)

        if let img = renderViewInWindow(view: popoverDark, size: CGSize(width: 420, height: 260)) {
            saveImage(img, to: assetsDir.appendingPathComponent("popover_dark.png").path)
        }

        // 2. Popover Light
        let popoverLight = ZStack {
            TranslationContentView(
                originalText: sampleEnglish,
                translatedText: sampleRussian,
                isLoading: false,
                isStreaming: false,
                errorMessage: nil,
                targetLanguage: targetLangRu,
                onCopy: {},
                onReplace: {},
                onClose: {}
            )
            .padding(20)
        }
        .preferredColorScheme(.light)
        .frame(width: 420, height: 260)

        if let img = renderViewInWindow(view: popoverLight, size: CGSize(width: 420, height: 260)) {
            saveImage(img, to: assetsDir.appendingPathComponent("popover_light.png").path)
        }

        // 3. Settings AI Model
        let settingsAi = SettingsView(initialTab: .aiModel)
            .preferredColorScheme(.dark)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(15)

        if let img = renderViewInWindow(view: settingsAi, size: CGSize(width: 710, height: 520), isOpaque: true) {
            saveImage(img, to: assetsDir.appendingPathComponent("settings_preview.png").path)
        }

        // 4. Settings Translation & Shortcuts
        let settingsTranslation = SettingsView(initialTab: .translation)
            .preferredColorScheme(.dark)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(15)

        if let img = renderViewInWindow(view: settingsTranslation, size: CGSize(width: 710, height: 520), isOpaque: true) {
            saveImage(img, to: assetsDir.appendingPathComponent("settings_translation.png").path)
        }

        // 5. Settings Rewrite & Proofreading
        let settingsRewrite = SettingsView(initialTab: .rewrite)
            .preferredColorScheme(.dark)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(15)

        if let img = renderViewInWindow(view: settingsRewrite, size: CGSize(width: 710, height: 520), isOpaque: true) {
            saveImage(img, to: assetsDir.appendingPathComponent("settings_rewrite.png").path)
        }
    }
}
