import Testing
import SwiftUI
import Foundation
import Carbon
import AppKit
@testable import LightL

extension LightLTests {
    @Test("AppIcon resolves to valid image asset")
    func appIconLoads() {
        let icon = NSImage.appIcon
        #expect(icon.isValid)
        #expect(icon.size.width > 0)
        #expect(icon.size.height > 0)
    }

    @Test("FloatingTranslationPanel triggers onDismiss callback on dismissal")
    @MainActor
    func floatingTranslationPanelDismissCallback() {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return
        }
        let panel = FloatingTranslationPanel()
        var dismissed = false
        panel.onDismiss = {
            dismissed = true
        }

        panel.dismiss()
        #expect(dismissed == true)
    }

    @Test("SettingsWindowController lifecycle and window delegate windowWillClose handling")
    @MainActor
    func settingsWindowControllerLifecycleAndDelegate() {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return
        }
        let controller = SettingsWindowController.shared

        // Show window
        controller.show()
        #expect(controller.currentWindow != nil)

        guard let window = controller.currentWindow else {
            Issue.record("Settings window was not created")
            return
        }

        #expect(window.delegate === controller)
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
        #expect(window.styleMask.contains(.miniaturizable))
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.isReleasedWhenClosed == false)
        #expect(window.titlebarAppearsTransparent == true)

        // Re-showing existing window reuses the instance
        controller.show()
        #expect(controller.currentWindow === window)

        // Simulate window close delegate notification
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
        #expect(controller.currentWindow == nil)

        // Subsequent show() recreates a fresh window
        controller.show()
        #expect(controller.currentWindow != nil)
        let freshWindow = controller.currentWindow!
        #expect(freshWindow !== window)

        // Cleanup
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: freshWindow))
        #expect(controller.currentWindow == nil)
    }

    @Test("StatusBarController menu suppresses Accessibility item when permission is granted")
    @MainActor
    func statusBarMenuAccessibilityItem() {
        let isGranted = TextCaptureService.isAccessibilityGranted(prompt: false)
        let controller = StatusBarController()
        controller.rebuildMenu()

        // Test menuNeedsUpdate
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        let titles = menu.items.map(\.title)

        // Test version badge in header
        let firstItem = menu.items.first
        #expect(firstItem?.title == "LightL AI")
        #expect(firstItem?.badge != nil)
        #expect(firstItem?.badge?.stringValue == StatusBarController.appVersion)

        if isGranted {
            #expect(!titles.contains { $0.contains("Accessibility") || $0.contains("Универсальный доступ") })
        } else {
            #expect(titles.contains { $0.contains("Accessibility") || $0.contains("Универсальный доступ") })
        }

        controller.destroy()
    }

    @Test("VisualEffectView initializer with cornerRadius and layer masking properties")
    @MainActor
    func visualEffectViewCornerRadiusAndMasking() {
        // 1. Initializer with custom cornerRadius
        let customView = VisualEffectView(material: .popover, blendingMode: .behindWindow, cornerRadius: 18)
        #expect(customView.material == .popover)
        #expect(customView.blendingMode == .behindWindow)
        #expect(customView.cornerRadius == 18)

        // 2. Applied to NSVisualEffectView: layer masking is enabled when cornerRadius > 0
        let nsView = NSVisualEffectView()
        customView.apply(to: nsView)
        #expect(nsView.material == .popover)
        #expect(nsView.blendingMode == .behindWindow)
        #expect(nsView.state == .active)
        #expect(nsView.wantsLayer == true)
        #expect(nsView.layer?.cornerRadius == 18)
        #expect(nsView.layer?.masksToBounds == true)

        // 3. Default initializer sets cornerRadius = 0 and masksToBounds = false
        let defaultView = VisualEffectView(material: .selection, blendingMode: .withinWindow)
        #expect(defaultView.cornerRadius == 0)
        #expect(defaultView.material == .selection)
        #expect(defaultView.blendingMode == .withinWindow)

        let defaultNSView = NSVisualEffectView()
        defaultView.apply(to: defaultNSView)
        #expect(defaultNSView.layer?.cornerRadius == 0)
        #expect(defaultNSView.layer?.masksToBounds == false)
    }

    @Test("FloatingTranslationPanel passes canReplace to the content view")
    @MainActor
    func panelCanReplace() {
        let panel = FloatingTranslationPanel()
        panel.canReplace = false
        panel.updateTranslation(originalText: "a", translatedText: "b", targetLanguage: LanguageModel.defaultTarget, onCopy: {}, onReplace: {})
        let view = (panel.contentView as? NSHostingView<TranslationContentView>)?.rootView
        #expect(view?.canReplace == false)
    }
}
