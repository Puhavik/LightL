import Foundation
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock, run as Menu Bar accessory
        NSApplication.shared.setActivationPolicy(.accessory)

        AppCoordinator.shared.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppCoordinator.shared.stop()
    }
}
