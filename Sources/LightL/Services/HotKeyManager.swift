import Foundation
import AppKit
import Carbon
import os

private final class DoubleTapTracker: @unchecked Sendable {
    private var lastTime: UInt64 = 0
    private let intervalNanoseconds: UInt64 = 380_000_000 // 380ms
    private var lock = os_unfair_lock()

    func reset() {
        os_unfair_lock_lock(&lock)
        lastTime = 0
        os_unfair_lock_unlock(&lock)
    }

    func recordAndCheckDoubleTap() -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        let diff = now - lastTime
        if lastTime != 0 && diff <= intervalNanoseconds {
            lastTime = 0
            return true
        } else {
            lastTime = now
            return false
        }
    }
}

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    public var onTranslate: (() -> Void)?
    public var onRewrite: (() -> Void)?

    private var translateHotKeyRef: EventHotKeyRef?
    private var rewriteHotKeyRef: EventHotKeyRef?

    private var eventHandlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private let doubleTapTracker = DoubleTapTracker()

    private init() {
        installCarbonEventHandler()
    }

    public func updateHotKeys(
        translateShortcut: ShortcutModel,
        rewriteShortcut: ShortcutModel,
        enableDoubleCmdC: Bool
    ) {
        unregisterAll()
        registerTranslate(shortcut: translateShortcut)
        registerRewrite(shortcut: rewriteShortcut)
        setupDoubleCmdCMonitor(enabled: enableDoubleCmdC)
    }

    private func registerTranslate(shortcut: ShortcutModel) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C54_5231), id: 1) // "LTR1"
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &translateHotKeyRef
        )
        if status != noErr {
            print("[HotKeyManager] Failed to register translate hotkey: \(status)")
        }
    }

    private func registerRewrite(shortcut: ShortcutModel) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C54_5232), id: 2) // "LTR2"
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &rewriteHotKeyRef
        )
        if status != noErr {
            print("[HotKeyManager] Failed to register rewrite hotkey: \(status)")
        }
    }

    private func unregisterAll() {
        if let ref = translateHotKeyRef {
            UnregisterEventHotKey(ref)
            translateHotKeyRef = nil
        }
        if let ref = rewriteHotKeyRef {
            UnregisterEventHotKey(ref)
            rewriteHotKeyRef = nil
        }
    }

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr else { return noErr }

            Task { @MainActor in
                if hotKeyID.id == 1 {
                    HotKeyManager.shared.onTranslate?()
                } else if hotKeyID.id == 2 {
                    HotKeyManager.shared.onRewrite?()
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandlerRef)
    }

    private func setupDoubleCmdCMonitor(enabled: Bool) {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        guard enabled else { return }

        let tracker = doubleTapTracker
        // Zero-allocation filter: ignores all non-Cmd+C keys immediately without creating Tasks
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let isCmdOnly = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            let isC = event.keyCode == UInt16(kVK_ANSI_C)

            guard isC && isCmdOnly else {
                tracker.reset()
                return
            }

            if tracker.recordAndCheckDoubleTap() {
                Task { @MainActor in
                    // Yield briefly for target app to finish updating clipboard
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    HotKeyManager.shared.onTranslate?()
                }
            }
        }
    }
}
