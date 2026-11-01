import Foundation
import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var activeAnimationTask: Task<Void, Never>?
    public private(set) var popover: NSPopover?
    public let viewModel: StatusBarPopoverViewModel
    private var popoverClosedAt: TimeInterval = 0

    public var isPopoverVisible: Bool {
        popover?.isShown ?? false
    }

    public var isMenuVisible: Bool {
        isPopoverVisible
    }

    private let errorIconName = "exclamationmark.triangle.fill"
    private let loadingIconName = "arrow.triangle.2.circlepath"

    public static var appVersion: String {
        let raw = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
            ?? "dev"
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "dev" }
        return (trimmed == "dev" || trimmed.hasPrefix("v")) ? trimmed : "v\(trimmed)"
    }

    public static let defaultMenuBarIcon: NSImage = {
        if let img = Bundle.main.image(forResource: "MenuBarIcon") {
            img.isTemplate = true
            return img
        }
        if let resourceUrl = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: resourceUrl) {
            img.isTemplate = true
            return img
        }
        #if SWIFT_PACKAGE
        if Bundle.main.bundleURL.pathExtension != "app", let img = Bundle.module.image(forResource: "MenuBarIcon") {
            img.isTemplate = true
            return img
        }
        #endif
        return drawVectorMenuBarIcon()
    }()

    public static func drawVectorMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
            context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            context.setLineWidth(2.0)
            let lPath = CGMutablePath()
            lPath.move(to: CGPoint(x: 4.2, y: 3.8))
            lPath.addLine(to: CGPoint(x: 4.2, y: 14.2))
            lPath.addLine(to: CGPoint(x: 9.8, y: 14.2))
            context.addPath(lPath)
            context.strokePath()
            
            let center = CGPoint(x: 12.8, y: 6.8)
            let r: CGFloat = 3.8
            let p = r * 0.16
            let sparkPath = CGMutablePath()
            sparkPath.move(to: CGPoint(x: center.x, y: center.y - r))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y), control: CGPoint(x: center.x + p, y: center.y - p))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r), control: CGPoint(x: center.x + p, y: center.y + p))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y), control: CGPoint(x: center.x - p, y: center.y + p))
            sparkPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r), control: CGPoint(x: center.x - p, y: center.y - p))
            sparkPath.closeSubpath()
            context.addPath(sparkPath)
            context.fillPath()
            
            return true
        }
        img.isTemplate = true
        return img
    }

    private var normalIcon: NSImage {
        Self.defaultMenuBarIcon
    }

    public var onOpenSettings: (() -> Void)?

    public init(viewModel: StatusBarPopoverViewModel = StatusBarPopoverViewModel()) {
        self.viewModel = viewModel
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = normalIcon
            button.imagePosition = .imageOnly
            button.toolTip = L10n.tr(ru: "LightL — AI переводчик и редактор", en: "LightL — AI Translator & Editor")
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
        }
    }

    @objc private func statusBarButtonClicked(_ sender: AnyObject?) {
        togglePopover()
    }

    public func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            let now = ProcessInfo.processInfo.systemUptime
            if now - popoverClosedAt < 0.15 {
                return
            }
            showPopover(relativeTo: button)
        }
    }

    public func showPopover(relativeTo button: NSStatusBarButton) {
        let pop = ensurePopover()
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = pop.contentViewController?.view.window {
            window.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closePopover() {
        popover?.performClose(nil)
    }

    private func ensurePopover() -> NSPopover {
        if let existing = popover {
            return existing
        }
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentSize = NSSize(width: 340, height: 360)
        pop.delegate = self
        let view = StatusBarPopoverView(
            viewModel: viewModel,
            onOpenSettings: { [weak self] in
                self?.closePopover()
                if let onOpenSettings = self?.onOpenSettings {
                    onOpenSettings()
                } else {
                    SettingsWindowController.shared.show()
                }
            },
            onClose: { [weak self] in
                self?.closePopover()
            }
        )
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame.size = NSSize(width: 340, height: 360)
        pop.contentViewController = hostingController
        self.popover = pop
        return pop
    }

    public func popoverDidClose(_ notification: Notification) {
        popoverClosedAt = ProcessInfo.processInfo.systemUptime
    }

    public func destroy() {
        stopActiveAnimation()
        closePopover()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    public func setLoading(_ loading: Bool) {
        guard let button = statusItem?.button else { return }
        stopActiveAnimation()
        if loading {
            let img = NSImage(
                systemSymbolName: loadingIconName,
                accessibilityDescription: L10n.tr(ru: "Загрузка...", en: "Loading...")
            )
            button.image = img
            button.contentTintColor = NSColor.systemBlue
        } else {
            resetNormalIcon()
        }
    }

    public func triggerErrorBlink(message: String) {
        guard let button = statusItem?.button else { return }
        stopActiveAnimation()

        button.toolTip = L10n.tr(ru: "Ошибка: \(message)", en: "Error: \(message)")

        activeAnimationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let maxBlinks = 6
            for i in 0..<maxBlinks {
                if Task.isCancelled { break }
                let isErrorState = (i % 2 == 0)
                if isErrorState {
                    button.image = NSImage(
                        systemSymbolName: self.errorIconName,
                        accessibilityDescription: L10n.tr(ru: "Ошибка", en: "Error")
                    )
                    button.contentTintColor = NSColor.systemRed
                } else {
                    button.image = self.normalIcon
                    button.contentTintColor = nil
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            guard !Task.isCancelled else { return }
            self.resetNormalIcon()
        }
    }

    public func triggerSuccessFlash() {
        guard let button = statusItem?.button else { return }
        stopActiveAnimation()
        button.contentTintColor = NSColor.systemGreen
        activeAnimationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.resetNormalIcon()
        }
    }

    private func resetNormalIcon() {
        guard let button = statusItem?.button else { return }
        button.image = normalIcon
        button.contentTintColor = nil
        button.toolTip = L10n.tr(ru: "LightL — AI переводчик и редактор", en: "LightL — AI Translator & Editor")
    }

    private func stopActiveAnimation() {
        activeAnimationTask?.cancel()
        activeAnimationTask = nil
        resetNormalIcon()
    }
}
