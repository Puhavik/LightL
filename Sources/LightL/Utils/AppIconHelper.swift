import Foundation
import AppKit

extension NSImage {
    /// Authentic LightL application icon (multi-resolution AppIcon.icns / AppIcon_1024.png).
    public static var appIcon: NSImage {
        // 1. Try Bundle.main (when running inside .app bundle)
        if let img = Bundle.main.image(forResource: "AppIcon") {
            return img
        }
        if let img = Bundle.main.image(forResource: "AppIcon_1024") {
            return img
        }
        if let url = Bundle.main.url(forResource: "AppIcon_1024", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }

        // 2. Try Bundle.module (when running via SPM). It traps if the resource bundle cannot be opened,
        // so never touch it inside a packaged .app.
        #if SWIFT_PACKAGE
        if Bundle.main.bundleURL.pathExtension != "app", let img = Bundle.module.image(forResource: "AppIcon") {
            return img
        }
        if Bundle.main.bundleURL.pathExtension != "app", let img = Bundle.module.image(forResource: "AppIcon_1024") {
            return img
        }
        if Bundle.main.bundleURL.pathExtension != "app",
           let url = Bundle.module.url(forResource: "AppIcon_1024", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if Bundle.main.bundleURL.pathExtension != "app",
           let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        #endif

        // 3. Fallback to NSImage.applicationIconName
        if let appIcon = NSImage(named: NSImage.applicationIconName), appIcon.isValid {
            return appIcon
        }

        return NSImage()
    }
}
