import AppKit
import ServiceManagement

@MainActor
public enum LaunchAtLogin {
    public static var status: SMAppService.Status { SMAppService.mainApp.status }

    public static var isEnabled: Bool { status == .enabled }

    public static var needsApproval: Bool { status == .requiresApproval }

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
