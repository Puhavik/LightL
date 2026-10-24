import AppKit
import ServiceManagement

/// Launch-at-login via SMAppService. The system (System Settings → Login Items) is the single
/// source of truth: nothing is persisted in-app and the app never registers itself, so default is off.
@MainActor
public enum LaunchAtLogin {
    public static var status: SMAppService.Status { SMAppService.mainApp.status }

    public static var isEnabled: Bool { status == .enabled }

    /// Registered, but the user still has to approve it in System Settings.
    public static var needsApproval: Bool { status == .requiresApproval }

    /// What the toggle should show: on, or waiting for the user's approval.
    public static var isRequested: Bool { isEnabled || needsApproval }

    public static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            presentError(error)
        }
        if enabled, service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    public static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.tr(ru: "Не удалось изменить автозапуск", en: "Couldn't change Launch at Login")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
