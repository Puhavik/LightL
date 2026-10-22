import Foundation
import AppKit
import SwiftUI
import Carbon

@MainActor
public final class FloatingTranslationPanel: NSPanel {
    private var clickMonitor: Any?
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?
    private var hostingView: NSHostingView<TranslationContentView>?
    private var currentPosition: EitherPointOrRect?

    public override var canBecomeKey: Bool {
        return true
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
            errorMessage: nil,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: onReplace
        )

        positionWindow(near: pointOrRect)
        self.orderFront(nil)
        startMonitors()
    }

    public func updateTranslation(
        originalText: String,
        translatedText: String,
        targetLanguage: LanguageModel,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    ) {
        updateContent(
            originalText: originalText,
            translatedText: translatedText,
            isLoading: false,
            errorMessage: nil,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: onReplace
        )

        if let pos = currentPosition {
            positionWindow(near: pos)
        }
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
            errorMessage: error,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: onReplace
        )

        if let pos = currentPosition {
            positionWindow(near: pos)
        }
    }

    public func dismiss() {
        self.orderOut(nil)
        stopMonitors()
        self.currentPosition = nil
    }

    private func updateContent(
        originalText: String,
        translatedText: String?,
        isLoading: Bool,
        errorMessage: String?,
        targetLanguage: LanguageModel,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void
    ) {
        let view = TranslationContentView(
            originalText: originalText,
            translatedText: translatedText,
            isLoading: isLoading,
            errorMessage: errorMessage,
            targetLanguage: targetLanguage,
            onCopy: onCopy,
            onReplace: { [weak self] in
                self?.dismiss()
                Task { @MainActor in
                    // Small delay to allow macOS WindowServer to restore active focus to the target app
                    try? await Task.sleep(nanoseconds: 80_000_000)
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

        // Adjust window size based on fitting size
        if let hosting = hostingView {
            hosting.layoutSubtreeIfNeeded()
            let fitting = hosting.fittingSize
            var frame = self.frame
            frame.size = fitting
            self.setFrame(frame, display: true, animate: false)
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
            if targetOrigin.y < screenFrame.minY {
                targetOrigin.y = rect.maxY + 8
            }
        case .point(let pt):
            // Place slightly to bottom-right of mouse pointer
            targetOrigin = CGPoint(x: pt.x + 8, y: pt.y - panelSize.height - 8)
        }

        // Keep inside screen bounds
        if targetOrigin.x + panelSize.width > screenFrame.maxX - 10 {
            targetOrigin.x = screenFrame.maxX - panelSize.width - 10
        }
        if targetOrigin.x < screenFrame.minX + 10 {
            targetOrigin.x = screenFrame.minX + 10
        }
        if targetOrigin.y < screenFrame.minY + 10 {
            targetOrigin.y = screenFrame.minY + 10
        }
        if targetOrigin.y + panelSize.height > screenFrame.maxY - 10 {
            targetOrigin.y = screenFrame.maxY - panelSize.height - 10
        }

        self.setFrameOrigin(targetOrigin)
    }

    private func startMonitors() {
        stopMonitors()

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let mouseLoc = NSEvent.mouseLocation
            if !self.frame.contains(mouseLoc) {
                self.dismiss()
            }
        }

        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.dismiss()
            }
        }

        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    private func stopMonitors() {
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
