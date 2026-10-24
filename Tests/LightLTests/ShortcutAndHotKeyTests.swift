import Testing
import SwiftUI
import Foundation
import Carbon
import AppKit
@testable import LightL

extension LightLTests {
    @Test("ShortcutModel default values and display strings")
    func shortcutDefaultsAndDisplayString() {
        let translate = ShortcutModel.defaultTranslate
        #expect(translate.keyCode == UInt32(kVK_ANSI_C))
        #expect(translate.displayString.contains("⌘"))
        #expect(translate.displayString.contains("⌥"))
        #expect(translate.displayString.contains("C"))

        let rewrite = ShortcutModel.defaultRewrite
        #expect(rewrite.keyCode == UInt32(kVK_ANSI_W))
        #expect(rewrite.displayString.contains("⌘"))
        #expect(rewrite.displayString.contains("⌥"))
        #expect(rewrite.displayString.contains("W"))
    }

    @Test("ShortcutModel Codable roundtrip")
    func shortcutCodableRoundtrip() throws {
        let original = ShortcutModel(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | shiftKey))
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ShortcutModel.self, from: data)

        #expect(decoded == original)
        #expect(decoded.keyCode == UInt32(kVK_ANSI_T))
    }

    @Test("Coordinate conversion formula: Carbon/AX (top-left) to Cocoa (bottom-left)")
    func coordinateConversionFormula() {
        let primaryScreenHeight: CGFloat = 1080
        let axRect = CGRect(x: 100, y: 50, width: 200, height: 20) // near top of screen

        let cocoaY = primaryScreenHeight - axRect.origin.y - axRect.height
        let cocoaRect = CGRect(x: axRect.origin.x, y: cocoaY, width: axRect.width, height: axRect.height)

        #expect(cocoaRect.origin.y == 1010) // Near top of Cocoa coordinate system
        #expect(cocoaRect.origin.x == 100)
        #expect(cocoaRect.height == 20)
    }

    @Test("ShortcutModel rejects reserved system shortcuts like ⌘C, ⌘V, ⌘Q and permits combo modifiers")
    func shortcutModelSystemReservedBlacklist() {
        let cmdOnly = UInt32(cmdKey)
        let cmdOpt = UInt32(cmdKey | optionKey)
        let cmdShift = UInt32(cmdKey | shiftKey)

        // Reserved single Cmd shortcuts
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_C), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_V), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_X), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_Z), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_A), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_Q), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_W), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_Space), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_Tab), modifiers: cmdOnly))

        // Permitted shortcuts with Option, Shift or Control
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_C), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_W), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_C), modifiers: cmdShift))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_T), modifiers: cmdOnly))
    }

    @Test("DoubleTapTracker interval logic: respects timing threshold and resets on detection")
    func doubleTapIntervalLogic() {
        let tracker = DoubleTapTracker(intervalNanoseconds: 380_000_000)

        // First tap: should not trigger
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_000_000_000))

        // Second tap at 200ms (< 380ms threshold): should trigger double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 1_200_000_000))

        // Third tap 50ms after detection: should reset and treat as new first tap (not trigger)
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_250_000_000))

        // Fourth tap 450ms later (> 380ms threshold): interval expired, should not trigger
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_700_000_000))

        // Fifth tap 100ms after fourth tap: should trigger double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 1_800_000_000))
    }

    @Test("DoubleTapTracker reset behavior clears state and breaks double-tap chain")
    func doubleTapResetBehavior() {
        let tracker = DoubleTapTracker(intervalNanoseconds: 380_000_000)

        // First tap: records state
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_000_000_000))

        // Explicit reset clears timestamp
        tracker.reset()

        // Next tap at 50ms after reset: must not trigger because state was cleared
        #expect(!tracker.recordAndCheckDoubleTap(now: 1_050_000_000))

        // Subsequent tap 100ms later: now triggers double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 1_150_000_000))
    }

    @Test("DoubleTapTracker underflow prevention handles backwards clock anomalies safely")
    func doubleTapUnderflowPrevention() {
        let tracker = DoubleTapTracker(intervalNanoseconds: 380_000_000)

        // First tap at high monotonic timestamp
        #expect(!tracker.recordAndCheckDoubleTap(now: 5_000_000_000))

        // Clock jumps backwards (e.g. system time skew or anomaly)
        // Must prevent UInt64 underflow crash and safely return false
        #expect(!tracker.recordAndCheckDoubleTap(now: 2_000_000_000))

        // Another backwards step to 500ms (lower than 2_000_000_000): must not crash
        #expect(!tracker.recordAndCheckDoubleTap(now: 500_000_000))

        // Normal subsequent tap forward: 100ms later (600_000_000): should trigger double-tap
        #expect(tracker.recordAndCheckDoubleTap(now: 600_000_000))

        // Default timestamp parameter invocation does not crash
        let liveTracker = DoubleTapTracker()
        #expect(!liveTracker.recordAndCheckDoubleTap())
    }

    @Test("ShortcutModel comprehensive reserved shortcuts and glyph rendering")
    func shortcutModelValidationAndGlyphs() {
        let cmdOnly = UInt32(cmdKey)
        let cmdOpt = UInt32(cmdKey | optionKey)
        let cmdShift = UInt32(cmdKey | shiftKey)
        let cmdCtrl = UInt32(cmdKey | controlKey)

        // All 9 reserved single Cmd shortcuts
        let reservedKeys: [Int] = [
            kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X, kVK_ANSI_Z,
            kVK_ANSI_A, kVK_ANSI_Q, kVK_ANSI_W, kVK_Space, kVK_Tab
        ]
        for key in reservedKeys {
            #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdOnly))
            // Permitted with combo modifiers
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdOpt))
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdShift))
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdCtrl))
        }

        // Permitted single Cmd shortcuts
        let permittedKeys: [Int] = [
            kVK_ANSI_B, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_K, kVK_ANSI_T,
            kVK_ANSI_1, kVK_ANSI_9, kVK_Return, kVK_Delete, kVK_Escape
        ]
        for key in permittedKeys {
            #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(key), modifiers: cmdOnly))
        }

        // Glyph order: Control ⌃, Option ⌥, Shift ⇧, Command ⌘
        let allMods = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let fullShortcut = ShortcutModel(keyCode: UInt32(kVK_ANSI_A), modifiers: allMods)
        #expect(fullShortcut.displayString == "⌃⌥⇧⌘A")

        // Special keys display names
        #expect(ShortcutModel(keyCode: UInt32(kVK_Space), modifiers: cmdOpt).displayString == "⌥⌘Space")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Return), modifiers: cmdOpt).displayString == "⌥⌘⏎")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Tab), modifiers: cmdOpt).displayString == "⌥⌘⇥")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Delete), modifiers: cmdOpt).displayString == "⌥⌘⌫")
        #expect(ShortcutModel(keyCode: UInt32(kVK_Escape), modifiers: cmdOpt).displayString == "⌥⌘⎋")

        // Numeric keys
        #expect(ShortcutModel(keyCode: UInt32(kVK_ANSI_5), modifiers: cmdOnly).displayString == "⌘5")

        // Unknown key fallback
        #expect(ShortcutModel(keyCode: 9999, modifiers: cmdOnly).displayString == "⌘Key(9999)")
    }

    @Test("HotKeyManager.updateHotKeys returns tuple (translateSuccess: Bool, rewriteSuccess: Bool)")
    @MainActor
    func hotKeyManagerUpdateHotKeysReturnTuple() {
        // 1. Update hotkeys with defaults
        let result = HotKeyManager.shared.updateHotKeys(
            translateShortcut: ShortcutModel.defaultTranslate,
            rewriteShortcut: ShortcutModel.defaultRewrite,
            enableDoubleCmdC: false
        )

        // Verify type and structure of return tuple
        let translateOk: Bool = result.translateSuccess
        let rewriteOk: Bool = result.rewriteSuccess
        #expect(result.0 == translateOk)
        #expect(result.1 == rewriteOk)

        // 2. Update hotkeys with custom shortcuts
        let customTranslate = ShortcutModel(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(cmdKey | optionKey))
        let customRewrite = ShortcutModel(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | optionKey))
        let customResult = HotKeyManager.shared.updateHotKeys(
            translateShortcut: customTranslate,
            rewriteShortcut: customRewrite,
            enableDoubleCmdC: true
        )
        #expect(customResult.translateSuccess == customResult.0)
        #expect(customResult.rewriteSuccess == customResult.1)

        // 3. Restore to defaults
        let restoredResult = HotKeyManager.shared.updateHotKeys(
            translateShortcut: ShortcutModel.defaultTranslate,
            rewriteShortcut: ShortcutModel.defaultRewrite,
            enableDoubleCmdC: false
        )
        #expect(restoredResult.translateSuccess == restoredResult.0)
    }

    @Test("registering the same shortcut for translate and rewrite fails for the second one")
    @MainActor
    func duplicateShortcutsFail() {
        let shortcut = ShortcutModel(keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey))
        defer { HotKeyManager.shared.unregisterHotKeys() }
        let result = HotKeyManager.shared.updateHotKeys(translateShortcut: shortcut, rewriteShortcut: shortcut, enableDoubleCmdC: false)
        #expect(result.translateSuccess)
        #expect(!result.rewriteSuccess)
    }

    @Test("ShortcutModel rejects expanded system shortcuts (⌘S, ⌘O, ⌘H, ⌘M) and permits combo modifiers")
    func shortcutModelExpandedBlacklist() {
        let cmdOnly = UInt32(cmdKey)
        let cmdOpt = UInt32(cmdKey | optionKey)

        // Expanded reserved shortcuts
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_S), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_O), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_H), modifiers: cmdOnly))
        #expect(ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_M), modifiers: cmdOnly))

        // Same shortcuts with Option modifier are permitted
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_S), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_O), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_H), modifiers: cmdOpt))
        #expect(!ShortcutModel.isSystemReserved(keyCode: UInt32(kVK_ANSI_M), modifiers: cmdOpt))
    }

    @Test("HotKeyManager recheckDoubleCmdCMonitor runs safely")
    @MainActor
    func hotKeyManagerRecheckDoubleCmdCMonitor() {
        HotKeyManager.shared.recheckDoubleCmdCMonitor()
    }
}
