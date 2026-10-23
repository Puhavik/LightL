import Testing
import SwiftUI
import AppKit
@testable import LightL

@Suite("Screenshot Generation")
struct ScreenshotGenerator {

    @MainActor
    private func renderViewInWindow<V: View>(view: V, size: CGSize) -> NSImage? {
        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.appearance = NSAppearance(named: .darkAqua)
        win.isOpaque = false
        win.backgroundColor = .clear

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

    @MainActor
    @ViewBuilder
    private func windowMockup(tab: SettingsTab) -> some View {
        ZStack(alignment: .topLeading) {
            // macOS Window unified body
            HStack(spacing: 0) {
                // Sidebar background
                Color(red: 0.13, green: 0.13, blue: 0.15)
                    .frame(width: 205)

                // Divider line
                Color.white.opacity(0.08)
                    .frame(width: 1)

                // Detail content background (solid dark surface)
                Color(red: 0.16, green: 0.16, blue: 0.18)
            }

            // Real Settings View
            SettingsView(initialTab: tab)

            // macOS Window Traffic lights
            HStack(spacing: 7) {
                Circle().fill(Color(red: 1.0, green: 0.36, blue: 0.34)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.37)).frame(width: 11, height: 11)
            }
            .padding(.leading, 12)
            .padding(.top, 11)
        }
        .frame(width: 680, height: 490)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .padding(20)
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
            .padding(16)
        }
        .preferredColorScheme(.dark)
        .frame(width: 412, height: 252)

        if let img = renderViewInWindow(view: popoverDark, size: CGSize(width: 412, height: 252)) {
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
            .padding(16)
        }
        .preferredColorScheme(.light)
        .frame(width: 412, height: 252)

        if let img = renderViewInWindow(view: popoverLight, size: CGSize(width: 412, height: 252)) {
            saveImage(img, to: assetsDir.appendingPathComponent("popover_light.png").path)
        }

        // 3. Settings AI Model
        let settingsAi = windowMockup(tab: .aiModel)
        if let img = renderViewInWindow(view: settingsAi, size: CGSize(width: 720, height: 530)) {
            saveImage(img, to: assetsDir.appendingPathComponent("settings_preview.png").path)
        }

        // 4. Settings Translation & Shortcuts
        let settingsTranslation = windowMockup(tab: .translation)
        if let img = renderViewInWindow(view: settingsTranslation, size: CGSize(width: 720, height: 530)) {
            saveImage(img, to: assetsDir.appendingPathComponent("settings_translation.png").path)
        }

        // 5. Settings Rewrite & Proofreading
        let settingsRewrite = windowMockup(tab: .rewrite)
        if let img = renderViewInWindow(view: settingsRewrite, size: CGSize(width: 720, height: 530)) {
            saveImage(img, to: assetsDir.appendingPathComponent("settings_rewrite.png").path)
        }
    }
}
