import Foundation
import AppKit
import SwiftUI
import Carbon

@MainActor
public final class FloatingTranslationPanel: NSPanel {
    public var onDismiss: (() -> Void)?
    public var canReplace = true

    private var clickMonitor: Any?
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?
    private var spaceChangeObserver: (any NSObjectProtocol)?
    private var hostingView: NSHostingView<TranslationContentView>?
    private var currentPosition: EitherPointOrRect?
    private var isPlacedAbove: Bool = false

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func resignKey() {
        super.resignKey()
        dismiss()
    }

    public override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            dismiss()
            return
        }
        super.keyDown(with: event)
    }

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .popUpMenu
        self.hasShadow = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.animationBehavior = .utilityWindow
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    public func show(
        originalText: String,
        targetLanguage: LanguageModel,
        near pointOrRect: EitherPointOrRect,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    ) {
        self.currentPosition = pointOrRect

        updateContent(
            originalText: originalText,
            translatedText: nil,
            isLoading: true,
            isStreaming: false,
            errorMessage: nil,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: onReplace
        )

        positionWindow(near: pointOrRect)
        self.makeKeyAndOrderFront(nil)
        self.makeKey()
        startMonitors()
    }

    public func updateTranslation(
        originalText: String,
        translatedText: String,
        targetLanguage: LanguageModel,
        isStreaming: Bool = false,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    ) {
        updateContent(
            originalText: originalText,
            translatedText: translatedText,
            isLoading: false,
            isStreaming: isStreaming,
            errorMessage: nil,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: onReplace
        )
    }

    public func showError(
        originalText: String,
        error: String,
        targetLanguage: LanguageModel,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    ) {
        updateContent(
            originalText: originalText,
            translatedText: nil,
            isLoading: false,
            isStreaming: false,
            errorMessage: error,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: onReplace
        )
    }

    public func dismiss() {
        self.orderOut(nil)
        stopMonitors()
        self.currentPosition = nil
        self.isPlacedAbove = false
        self.contentView = nil
        self.hostingView = nil
        onDismiss?()
    }

    private func updateContent(
        originalText: String,
        translatedText: String?,
        isLoading: Bool,
        isStreaming: Bool = false,
        errorMessage: String?,
        targetLanguage: LanguageModel,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    ) {
        let view = TranslationContentView(
            originalText: originalText,
            translatedText: translatedText,
            isLoading: isLoading,
            isStreaming: isStreaming,
            errorMessage: errorMessage,
            canReplace: canReplace,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: { [weak self] in
                self?.dismiss()
                Task { @MainActor in
                    // Small delay to allow macOS WindowServer to restore active focus to the target app
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    if #available(macOS 14.0, *) {
                        NSWorkspace.shared.frontmostApplication?.activate()
                    } else {
                        NSWorkspace.shared.frontmostApplication?.activate(options: .activateIgnoringOtherApps)
                    }
                    onReplace()
                }
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )

        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            self.contentView = hosting
            self.hostingView = hosting
        }

        // Adjust window size based on fitting size, keeping anchored
        if let hosting = hostingView {
            hosting.layoutSubtreeIfNeeded()
            let fitting = hosting.fittingSize
            let oldFrame = self.frame

            var targetOrigin = oldFrame.origin
            if self.isVisible && oldFrame.height > 0 {
                // If placed below rect (or near point), anchor the TOP edge: newOrigin.y = oldFrame.maxY - fitting.height
                // If placed above rect, anchor the BOTTOM edge: newOrigin.y = oldFrame.minY
                targetOrigin.y = isPlacedAbove ? oldFrame.minY : (oldFrame.maxY - fitting.height)

                // Clamp targetOrigin within screenFrame bounds
                if let screen = self.screen ?? (currentPosition.flatMap { findTargetScreen(for: $0) }) ?? NSScreen.main ?? NSScreen.screens.first {
                    let screenFrame = screen.visibleFrame
                    let minX = screenFrame.minX + 10
                    let maxX = screenFrame.maxX - fitting.width - 10
                    if maxX >= minX {
                        targetOrigin.x = min(max(targetOrigin.x, minX), maxX)
                    } else {
                        targetOrigin.x = minX
                    }

                    let minY = screenFrame.minY + 10
                    let maxY = screenFrame.maxY - fitting.height - 10
                    if maxY >= minY {
                        targetOrigin.y = min(max(targetOrigin.y, minY), maxY)
                    } else {
                        targetOrigin.y = minY
                    }
                }
            }

            self.setFrame(NSRect(origin: targetOrigin, size: fitting), display: true, animate: false)
        }
    }

    private func findTargetScreen(for pointOrRect: EitherPointOrRect) -> NSScreen? {
        let testPoint: CGPoint
        switch pointOrRect {
        case .point(let pt):
            testPoint = pt
        case .rect(let rect):
            testPoint = CGPoint(x: rect.midX, y: rect.midY)
        }
        return NSScreen.screens.first(where: { $0.frame.contains(testPoint) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func positionWindow(near pointOrRect: EitherPointOrRect) {
        guard let screen = findTargetScreen(for: pointOrRect) else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = self.frame.size

        var targetOrigin: CGPoint

        switch pointOrRect {
        case .rect(let rect):
            // Place below the selection rect, or above if near bottom edge
            let x = rect.midX - (panelSize.width / 2)
            let y = rect.minY - panelSize.height - 8
            targetOrigin = CGPoint(x: x, y: y)

            // If it falls below screen bottom, place it above selection
            if targetOrigin.y < screenFrame.minY + 10 {
                targetOrigin.y = rect.maxY + 8
                isPlacedAbove = true
            } else {
                isPlacedAbove = false
            }
        case .point(let pt):
            // Place slightly to bottom-right of mouse pointer
            targetOrigin = CGPoint(x: pt.x + 8, y: pt.y - panelSize.height - 8)
            // If near bottom edge of screen, place above mouse pointer
            if targetOrigin.y < screenFrame.minY + 10 {
                targetOrigin.y = pt.y + 16
                isPlacedAbove = true
            } else {
                isPlacedAbove = false
            }
        }

        // Keep inside screen bounds
        let minX = screenFrame.minX + 10
        let maxX = screenFrame.maxX - panelSize.width - 10
        if maxX >= minX {
            targetOrigin.x = min(max(targetOrigin.x, minX), maxX)
        } else {
            targetOrigin.x = minX
        }

        let minY = screenFrame.minY + 10
        let maxY = screenFrame.maxY - panelSize.height - 10
        if maxY >= minY {
            targetOrigin.y = min(max(targetOrigin.y, minY), maxY)
        } else {
            targetOrigin.y = minY
        }

        self.setFrameOrigin(targetOrigin)
    }

    private func startMonitors() {
        stopMonitors()

        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismiss()
            }
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let mouseLoc = NSEvent.mouseLocation
                if !self.frame.contains(mouseLoc) {
                    self.dismiss()
                }
            }
        }

        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
            }
        }

        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                self.dismiss()
                return nil
            }
            return event
        }
    }

    private func stopMonitors() {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = escGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            escGlobalMonitor = nil
        }
        if let monitor = escLocalMonitor {
            NSEvent.removeMonitor(monitor)
            escLocalMonitor = nil
        }
    }

    public enum EitherPointOrRect: Sendable {
        case point(CGPoint)
        case rect(CGRect)
    }
}
