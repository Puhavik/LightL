import Foundation
import AppKit
import ApplicationServices
import Carbon

public struct CapturedSelection: Sendable {
    public let text: String
    public let bounds: CGRect?
    public let mouseLocation: CGPoint
    public let frontmostAppPID: pid_t?
    /// True when the text was read through the Accessibility API, so it can be re-read to detect selection changes.
    public let viaAccessibility: Bool

    public init(text: String, bounds: CGRect?, mouseLocation: CGPoint, frontmostAppPID: pid_t? = nil, viaAccessibility: Bool = false) {
        self.viaAccessibility = viaAccessibility
        self.text = text
        self.bounds = bounds
        self.mouseLocation = mouseLocation
        self.frontmostAppPID = frontmostAppPID
    }
}

@MainActor
public final class TextCaptureService: Sendable {
    public static let shared = TextCaptureService()

    internal static var accessibilityOverrideForTesting: Bool? = nil
    internal static var pasteboardRestoreDelayForTesting: UInt64? = nil
    internal static var skipSimulatePasteForTesting: Bool = false
    internal static var forcePasteboardFallbackForTesting: Bool = false

    private var savedOriginalItems: [NSPasteboardItem]?
    private var currentRestoreTask: Task<Void, Never>?

    internal var savedOriginalItemsCountForTesting: Int? {
        savedOriginalItems?.count
    }

    internal var hasPendingRestoreTaskForTesting: Bool {
        currentRestoreTask != nil
    }

    private init() {}

    public static func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        if let override = accessibilityOverrideForTesting {
            return override
        }
        if prompt {
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options = [promptKey: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Captures the selected text from the frontmost application.
    /// First attempts via Accessibility API, falls back to simulated ⌘+C.
    public func captureSelection() async -> CapturedSelection? {
        guard Self.isAccessibilityGranted(prompt: false) else { return nil }

        let mouseLoc = NSEvent.mouseLocation
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // 1. Try Accessibility API (direct process query for minimal latency)
        if let (axText, axBounds) = await getSelectionViaAccessibility(pid: frontmostPID), !axText.isEmpty {
            return CapturedSelection(text: axText, bounds: axBounds, mouseLocation: mouseLoc, frontmostAppPID: frontmostPID, viaAccessibility: true)
        }

        // 2. Fallback to synthetic Cmd+C
        if let clipboardText = await getSelectionViaClipboard(), !clipboardText.isEmpty,
           !(Self.copiesLineWhenSelectionEmpty(bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
             && Self.looksLikeEmptySelectionLineCopy(clipboardText)) {
            return CapturedSelection(text: clipboardText, bounds: nil, mouseLocation: mouseLoc, frontmostAppPID: frontmostPID)
        }

        return nil
    }

    /// Replaces the currently selected text in the active app with `newText`.
    /// First attempts via direct Accessibility API (zero clipboard modification, native Undo).
    /// Falls back to simulated ⌘+V with asynchronous clipboard restoration.
    /// When `original` is given and was captured via Accessibility, the replacement is skipped (returns false)
    /// if the current selection no longer matches it, so unrelated text is never overwritten.
    public func replaceSelection(with newText: String, verifying original: CapturedSelection? = nil) async -> Bool {
        guard Self.isAccessibilityGranted(prompt: false) else {
            return false
        }

        if let original {
            if original.viaAccessibility {
                let current = await getSelectionViaAccessibility(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier)?.0
                if current != original.text { return false }
            } else if await getSelectionViaClipboard(timeout: 0.5) != original.text {
                return false
            }
        }

        // 1. Try direct Accessibility API replacement (0ms, zero clipboard touch, preserves native Undo)
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if !Self.forcePasteboardFallbackForTesting,
           await Task.detached(priority: .userInitiated, operation: { Self.replaceSelectionViaAccessibility(newText: newText, pid: frontmostPID) }).value {
            return true
        }

        // 2. Fallback to synthetic Cmd+V via Pasteboard
        let pasteboard = NSPasteboard.general
        
        // Backup existing pasteboard items only if no previous restore is pending
        if currentRestoreTask != nil {
            // Previous restore is already pending — do not overwrite savedOriginalItems with intermediate text
        } else if savedOriginalItems == nil {
            savedOriginalItems = backupPasteboard(pasteboard)
        }

        // Set new text to pasteboard with transient markers to prevent history pollution in clipboard managers
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(newText, forType: .string)
        item.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.transient"))
        item.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        item.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"))
        pasteboard.writeObjects([item])

        let expectedChangeCount = pasteboard.changeCount

        // Restore the pasteboard in the background, counting the delay from the moment the paste was posted
        // so slow apps still read the replacement text.
        let delay = Self.pasteboardRestoreDelayForTesting ?? 2_000_000_000
        func scheduleRestore() {
            currentRestoreTask?.cancel()
            currentRestoreTask = Task { @MainActor [expectedChangeCount] in
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                if pasteboard.changeCount == expectedChangeCount, let original = self.savedOriginalItems {
                    self.restorePasteboard(pasteboard, items: original)
                }
                self.savedOriginalItems = nil
                self.currentRestoreTask = nil
            }
        }

        guard !Task.isCancelled else {
            scheduleRestore()
            return false
        }

        // Post simulated ⌘+V
        if !Self.skipSimulatePasteForTesting {
            await simulatePaste()
        }
        scheduleRestore()

        return !Task.isCancelled
    }

    nonisolated private static func replaceSelectionViaAccessibility(newText: String, pid: pid_t? = nil) -> Bool {
        let focusedAppElement: AXUIElement
        if let pid = pid {
            focusedAppElement = AXUIElementCreateApplication(pid)
        } else {
            let systemWide = AXUIElementCreateSystemWide()
            AXUIElementSetMessagingTimeout(systemWide, 0.25)
            var focusedAppValue: AnyObject?
            let appError = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue)
            guard appError == .success,
                  let focusedApp = focusedAppValue,
                  CFGetTypeID(focusedApp) == AXUIElementGetTypeID() else {
                return false
            }
            focusedAppElement = focusedApp as! AXUIElement
        }

        AXUIElementSetMessagingTimeout(focusedAppElement, 0.25)

        var focusedElementValue: AnyObject?
        let elError = AXUIElementCopyAttributeValue(focusedAppElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue)
        guard elError == .success,
              let focusedElement = focusedElementValue,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return false
        }

        let element = focusedElement as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.25)

        var isSettable: DarwinBoolean = false
        let settableStatus = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSettable)
        guard settableStatus == .success, isSettable.boolValue else {
            return false
        }

        let setStatus = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newText as CFTypeRef)
        return setStatus == .success
    }

    // MARK: - Accessibility Helpers

    private func getSelectionViaAccessibility(pid: pid_t? = nil) async -> (String, CGRect?)? {
        // AX IPC can block up to its messaging timeout per call; keep it off the main thread.
        guard let (text, axRect) = await Task.detached(priority: .userInitiated, operation: { Self.readSelectionViaAccessibility(pid: pid) }).value else {
            return nil
        }
        guard let axRect,
              let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first,
              primaryScreen.frame.height > 0 else {
            return (text, nil)
        }
        return (text, Self.convertCarbonAXRectToCocoa(axRect, primaryScreenHeight: primaryScreen.frame.height))
    }

    nonisolated private static func readSelectionViaAccessibility(pid: pid_t? = nil) -> (String, CGRect?)? {
        let focusedAppElement: AXUIElement
        if let pid = pid {
            focusedAppElement = AXUIElementCreateApplication(pid)
        } else {
            let systemWide = AXUIElementCreateSystemWide()
            AXUIElementSetMessagingTimeout(systemWide, 0.25)
            var focusedAppValue: AnyObject?
            let appError = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue)
            guard appError == .success,
                  let focusedApp = focusedAppValue,
                  CFGetTypeID(focusedApp) == AXUIElementGetTypeID() else {
                return nil
            }
            focusedAppElement = focusedApp as! AXUIElement
        }

        AXUIElementSetMessagingTimeout(focusedAppElement, 0.25)

        var focusedElementValue: AnyObject?
        let elError = AXUIElementCopyAttributeValue(focusedAppElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue)
        guard elError == .success,
              let focusedElement = focusedElementValue,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return nil
        }

        let element = focusedElement as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.25)

        var selectedTextValue: AnyObject?
        let textError = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        guard textError == .success, let text = selectedTextValue as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var bounds: CGRect?
        var selectedRangeValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
           let rangeVal = selectedRangeValue {
            var boundsVal: AnyObject?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeVal, &boundsVal) == .success,
               let val = boundsVal,
               CFGetTypeID(val) == AXValueGetTypeID() {
                var rect = CGRect.zero
                if AXValueGetValue(val as! AXValue, .cgRect, &rect), rect.width > 1, rect.height > 1 {
                    bounds = rect
                }
            }
        }

        return (text, bounds)
    }

    nonisolated static func copiesLineWhenSelectionEmpty(bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        let editors: Set<String> = [
            "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.visualstudio.code.oss",
            "com.todesktop.230313mzl4w4u92", "com.sublimetext.4", "com.sublimetext.3", "dev.zed.Zed"
        ]
        return editors.contains(id) || id.hasPrefix("com.jetbrains.")
    }

    /// Editors such as VS Code and JetBrains copy the whole caret line plus a trailing newline when nothing is selected.
    nonisolated static func looksLikeEmptySelectionLineCopy(_ text: String) -> Bool {
        text.hasSuffix("\n") && text.filter { $0 == "\n" }.count == 1
    }

    nonisolated public static func convertCarbonAXRectToCocoa(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let cocoaY = primaryScreenHeight - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: cocoaY, width: rect.width, height: rect.height)
    }

    // MARK: - Clipboard Simulation

    private func getSelectionViaClipboard(timeout: TimeInterval = 0.15) async -> String? {
        let pasteboard = NSPasteboard.general
        if currentRestoreTask != nil || savedOriginalItems != nil {
            if let original = savedOriginalItems {
                restorePasteboard(pasteboard, items: original)
                savedOriginalItems = nil
            }
            currentRestoreTask?.cancel()
            currentRestoreTask = nil
        }
        let previousChangeCount = pasteboard.changeCount
        let previousItems = backupPasteboard(pasteboard)

        await simulateCopy()

        // Fast adaptive polling (6ms -> 10ms -> 14ms)
        let start = Date()
        var updated = false
        var pollInterval: UInt64 = 6_000_000 // 6ms
        while Date().timeIntervalSince(start) < timeout {
            if Task.isCancelled { break }
            if pasteboard.changeCount != previousChangeCount {
                updated = true
                break
            }
            try? await Task.sleep(nanoseconds: pollInterval)
            if Task.isCancelled { break }
            if pollInterval < 18_000_000 {
                pollInterval += 4_000_000
            }
        }

        guard updated, let copiedString = pasteboard.string(forType: .string), !copiedString.isEmpty else {
            // Restore previous items if copy didn't yield anything
            restorePasteboard(pasteboard, items: previousItems)
            return nil
        }

        // Restore user clipboard
        restorePasteboard(pasteboard, items: previousItems)
        return copiedString
    }

    private func simulateCopy() async {
        let src = CGEventSource(stateID: .privateState)
        let cDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        cDown?.flags = .maskCommand
        cDown?.setIntegerValueField(.eventSourceUserData, value: 0x4C54_4C59)
        let cUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        cUp?.flags = .maskCommand
        cUp?.setIntegerValueField(.eventSourceUserData, value: 0x4C54_4C59)

        cDown?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 12_000_000) // 12ms pause so frontmost app processes key down before key up
        cUp?.post(tap: .cghidEventTap)
    }

    private func simulatePaste() async {
        let src = CGEventSource(stateID: .privateState)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 12_000_000) // 12ms pause so frontmost app processes key down before key up
        vUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Pasteboard Backup / Restore

    internal func backupPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        }
    }

    internal func restorePasteboard(_ pasteboard: NSPasteboard, items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let freshItems = items.map { item in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        }
        pasteboard.writeObjects(freshItems)
    }
}
