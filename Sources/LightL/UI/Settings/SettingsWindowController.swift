import Foundation
import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    public func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let win = NSWindow(contentViewController: hostingController)
        win.title = L10n.tr(ru: "Настройки LightL", en: "LightL Settings")
        // macOS 27 Unified Window with Full-Size Content View
        win.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.center()
        win.isReleasedWhenClosed = false
        win.setContentSize(NSSize(width: 680, height: 490))
        win.minSize = NSSize(width: 650, height: 470)

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }
}
