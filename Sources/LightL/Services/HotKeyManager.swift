import Foundation
import AppKit
import Carbon
import os

final class DoubleTapTracker: Sendable {
    private let state = OSAllocatedUnfairLock<UInt64>(initialState: 0)
    let intervalNanoseconds: UInt64

    init(intervalNanoseconds: UInt64 = 380_000_000) {
        self.intervalNanoseconds = intervalNanoseconds
    }

    func reset() {
        state.withLock { $0 = 0 }
    }

    func recordAndCheckDoubleTap(now: UInt64 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) -> Bool {
        state.withLock { lastTime in
            guard now >= lastTime else {
                lastTime = now
                return false
            }
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

    @discardableResult
    public func updateHotKeys(
        translateShortcut: ShortcutModel,
        rewriteShortcut: ShortcutModel,
        enableDoubleCmdC: Bool
    ) -> (translateSuccess: Bool, rewriteSuccess: Bool) {
        unregisterAll()
        let translateSuccess = registerTranslate(shortcut: translateShortcut)
        let rewriteSuccess = registerRewrite(shortcut: rewriteShortcut)
        setupDoubleCmdCMonitor(enabled: enableDoubleCmdC)
        return (translateSuccess, rewriteSuccess)
    }

    private func registerTranslate(shortcut: ShortcutModel) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C54_5231), id: 1) // "LTR1"
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &translateHotKeyRef
        )
        if status == -9878 /* eventHotKeyExistsErr */ {
            print("[HotKeyManager] Warning: translate hotkey already registered by another application (eventHotKeyExistsErr -9878), keyCode: \(shortcut.keyCode)")
        } else if status != noErr {
            print("[HotKeyManager] Failed to register translate hotkey: \(status), keyCode: \(shortcut.keyCode)")
        }
        return status == noErr
    }

    private func registerRewrite(shortcut: ShortcutModel) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C54_5232), id: 2) // "LTR2"
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &rewriteHotKeyRef
        )
        if status == -9878 /* eventHotKeyExistsErr */ {
            print("[HotKeyManager] Warning: rewrite hotkey already registered by another application (eventHotKeyExistsErr -9878), keyCode: \(shortcut.keyCode)")
        } else if status != noErr {
            print("[HotKeyManager] Failed to register rewrite hotkey: \(status), keyCode: \(shortcut.keyCode)")
        }
        return status == noErr
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
                let isTranslate = hotKeyID.signature == OSType(0x4C54_5231) && hotKeyID.id == 1
                let isRewrite = hotKeyID.signature == OSType(0x4C54_5232) && hotKeyID.id == 2
                if isTranslate {
                    HotKeyManager.shared.onTranslate?()
                } else if isRewrite {
                    HotKeyManager.shared.onRewrite?()
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandlerRef)
    }

    public func recheckDoubleCmdCMonitor() {
        setupDoubleCmdCMonitor(enabled: AppSettings.shared.doubleCmdCEnabled)
    }

    private func setupDoubleCmdCMonitor(enabled: Bool) {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        guard enabled else { return }

        let tracker = doubleTapTracker
        // Zero-allocation filter: ignores all non-Cmd+C keys immediately without creating Tasks
        // Checks explicitly for [.command, .shift, .control, .option] so CapsLock does not break Cmd+C
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == 0x4C54_4C59 { return }
            guard !event.isARepeat else { return }

            let isCmdOnly = event.modifierFlags.intersection([.command, .shift, .control, .option]) == .command
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
