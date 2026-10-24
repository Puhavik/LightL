import Testing
import SwiftUI
import Foundation
import Carbon
import AppKit
@testable import LightL

extension LightLTests {
    @Test("Multi-monitor coordinate conversion: secondary screen above primary (negative AX Y)")
    func coordinateConversionSecondaryScreenAbove() {
        let primaryScreenHeight: CGFloat = 1080
        // Secondary screen positioned above primary (Cocoa frame: 0, 1080, 1920, 1080)
        // In AX coordinates, Y=0 is top of primary screen, so above primary has negative Y
        let axRect = CGRect(x: 150, y: -500, width: 250, height: 40)

        let cocoaRect = TextCaptureService.convertCarbonAXRectToCocoa(axRect, primaryScreenHeight: primaryScreenHeight)

        // Cocoa Y = 1080 - (-500) - 40 = 1080 + 500 - 40 = 1540
        #expect(cocoaRect.origin.x == 150)
        #expect(cocoaRect.origin.y == 1540)
        #expect(cocoaRect.width == 250)
        #expect(cocoaRect.height == 40)
        // Cocoa Y=1540 is inside upper display range [1080, 2160]
        #expect(cocoaRect.origin.y >= 1080 && cocoaRect.origin.y < 2160)
    }

    @Test("Multi-monitor coordinate conversion: secondary screen below primary (negative Cocoa Y)")
    func coordinateConversionSecondaryScreenBelow() {
        let primaryScreenHeight: CGFloat = 1080
        // Secondary screen positioned below primary (Cocoa frame: 0, -1080, 1920, 1080)
        // In AX coordinates, primary spans 0..1080, secondary spans 1080..2160
        let axRect = CGRect(x: 120, y: 1400, width: 300, height: 50)

        let cocoaRect = TextCaptureService.convertCarbonAXRectToCocoa(axRect, primaryScreenHeight: primaryScreenHeight)

        // Cocoa Y = 1080 - 1400 - 50 = -370
        #expect(cocoaRect.origin.x == 120)
        #expect(cocoaRect.origin.y == -370)
        #expect(cocoaRect.width == 300)
        #expect(cocoaRect.height == 50)
        // Cocoa Y=-370 is inside lower display range [-1080, 0]
        #expect(cocoaRect.origin.y >= -1080 && cocoaRect.origin.y < 0)
    }

    @Test("Multi-monitor coordinate conversion: secondary screen with negative X and negative Y origins")
    func coordinateConversionNegativeXAndY() {
        let primaryScreenHeight: CGFloat = 1080
        // Screen to the left and below: AX X is negative, AX Y is > primary screen height
        let axRect = CGRect(x: -750, y: 1300, width: 200, height: 35)

        let cocoaRect = TextCaptureService.convertCarbonAXRectToCocoa(axRect, primaryScreenHeight: primaryScreenHeight)

        // Cocoa X = -750, Cocoa Y = 1080 - 1300 - 35 = -255
        #expect(cocoaRect.origin.x == -750)
        #expect(cocoaRect.origin.y == -255)
        #expect(cocoaRect.width == 200)
        #expect(cocoaRect.height == 35)
    }

    @Test("Multi-monitor coordinate conversion: Retina vs standard resolution point scaling")
    func coordinateConversionRetinaVsStandard() {
        let primaryHeightPoints: CGFloat = 1080

        // Standard display (1.0x scale): 1 pixel = 1 point
        let standardAxPoints = CGRect(x: 100, y: 50, width: 200, height: 40)
        let standardCocoa = TextCaptureService.convertCarbonAXRectToCocoa(standardAxPoints, primaryScreenHeight: primaryHeightPoints)
        #expect(standardCocoa.origin.y == 990)

        // Retina 2.0x display: raw physical pixels (200, 100, 400, 80) normalized to points
        let retina2xPixels = CGRect(x: 200, y: 100, width: 400, height: 80)
        let retina2xPoints = CGRect(
            x: retina2xPixels.origin.x / 2.0,
            y: retina2xPixels.origin.y / 2.0,
            width: retina2xPixels.width / 2.0,
            height: retina2xPixels.height / 2.0
        )
        let retina2xCocoa = TextCaptureService.convertCarbonAXRectToCocoa(retina2xPoints, primaryScreenHeight: primaryHeightPoints)
        #expect(retina2xCocoa.origin.y == 990)
        #expect(retina2xCocoa == standardCocoa)

        // Retina 3.0x display: raw physical pixels (300, 150, 600, 120) normalized to points
        let retina3xPixels = CGRect(x: 300, y: 150, width: 600, height: 120)
        let retina3xPoints = CGRect(
            x: retina3xPixels.origin.x / 3.0,
            y: retina3xPixels.origin.y / 3.0,
            width: retina3xPixels.width / 3.0,
            height: retina3xPixels.height / 3.0
        )
        let retina3xCocoa = TextCaptureService.convertCarbonAXRectToCocoa(retina3xPoints, primaryScreenHeight: primaryHeightPoints)
        #expect(retina3xCocoa.origin.y == 990)
        #expect(retina3xCocoa == standardCocoa)
    }

    @Test("TextCaptureService.replaceSelection re-entrancy protection and item preservation")
    @MainActor
    func textCaptureServiceReplaceSelectionReentrancyAndPreservation() async throws {
        // 1. Test backupPasteboard and restorePasteboard fidelity
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()
        let initialItem = NSPasteboardItem()
        let originalText = "Original User Clipboard \(UUID().uuidString)"
        initialItem.setString(originalText, forType: .string)
        pasteboard.writeObjects([initialItem])

        let backedUp = TextCaptureService.shared.backupPasteboard(pasteboard)
        #expect(!backedUp.isEmpty)
        #expect(backedUp.first?.string(forType: .string) == originalText)

        // 2. Configure testing hooks for TextCaptureService
        TextCaptureService.accessibilityOverrideForTesting = true
        TextCaptureService.skipSimulatePasteForTesting = true
        TextCaptureService.forcePasteboardFallbackForTesting = true
        TextCaptureService.pasteboardRestoreDelayForTesting = 80_000_000 // 80ms
        defer {
            TextCaptureService.accessibilityOverrideForTesting = nil
            TextCaptureService.skipSimulatePasteForTesting = false
            TextCaptureService.forcePasteboardFallbackForTesting = false
            TextCaptureService.pasteboardRestoreDelayForTesting = nil
        }

        // 3. First replacement: schedules restore task and backs up originalText
        let intermediate1 = "First Intermediate Replacement \(UUID().uuidString)"
        let replaced1 = await TextCaptureService.shared.replaceSelection(with: intermediate1)
        #expect(replaced1 == true)
        #expect(TextCaptureService.shared.hasPendingRestoreTaskForTesting == true)
        #expect(TextCaptureService.shared.savedOriginalItemsCountForTesting == 1)
        #expect(pasteboard.string(forType: .string) == intermediate1)

        // 4. Re-entrant second replacement: called immediately while first restore task is pending
        let intermediate2 = "Second Intermediate Replacement \(UUID().uuidString)"
        let replaced2 = await TextCaptureService.shared.replaceSelection(with: intermediate2)
        #expect(replaced2 == true)
        #expect(TextCaptureService.shared.hasPendingRestoreTaskForTesting == true)
        // Crucial re-entrancy proof: savedOriginalItems was preserved and NOT overwritten by intermediate1!
        #expect(TextCaptureService.shared.savedOriginalItemsCountForTesting == 1)
        #expect(pasteboard.string(forType: .string) == intermediate2)

        // 5. Wait for the restore task delay to elapse and yield to MainActor
        let deadline = Date().addingTimeInterval(1.5)
        while TextCaptureService.shared.hasPendingRestoreTaskForTesting && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        // 6. Verify full restoration to the original user text
        #expect(TextCaptureService.shared.hasPendingRestoreTaskForTesting == false)
        #expect(TextCaptureService.shared.savedOriginalItemsCountForTesting == nil)
        #expect(pasteboard.string(forType: .string) == originalText)
    }

    @Test("TextCaptureService restores the clipboard when replaceSelection is cancelled after the pasteboard write")
    @MainActor
    func replaceSelectionCancelledRestoresPasteboard() async throws {
        let pasteboard = NSPasteboard.general
        let originalText = "Original \(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(originalText, forType: .string)

        TextCaptureService.accessibilityOverrideForTesting = true
        TextCaptureService.skipSimulatePasteForTesting = true
        TextCaptureService.forcePasteboardFallbackForTesting = true
        TextCaptureService.pasteboardRestoreDelayForTesting = 80_000_000
        defer {
            TextCaptureService.accessibilityOverrideForTesting = nil
            TextCaptureService.skipSimulatePasteForTesting = false
            TextCaptureService.forcePasteboardFallbackForTesting = false
            TextCaptureService.pasteboardRestoreDelayForTesting = nil
        }

        let task = Task { @MainActor in
            await TextCaptureService.shared.replaceSelection(with: "Replacement \(UUID().uuidString)")
        }
        task.cancel()
        #expect(await task.value == false)

        let deadline = Date().addingTimeInterval(1.5)
        while TextCaptureService.shared.hasPendingRestoreTaskForTesting && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        #expect(pasteboard.string(forType: .string) == originalText)
    }

    @Test("Clipboard capture treats a single line with a trailing newline as an empty selection")
    func emptySelectionLineCopy() {
        #expect(TextCaptureService.looksLikeEmptySelectionLineCopy("let x = 1\n"))
        #expect(TextCaptureService.looksLikeEmptySelectionLineCopy("\n"))
        #expect(!TextCaptureService.looksLikeEmptySelectionLineCopy("let x = 1"))
        #expect(!TextCaptureService.looksLikeEmptySelectionLineCopy("a\nb\n"))
        #expect(!TextCaptureService.looksLikeEmptySelectionLineCopy("a\nb"))
    }

    @Test("A pending restore is reported between writing the replacement and scheduling the restore")
    @MainActor
    func pendingRestoreWindow() async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("Original \(UUID().uuidString)", forType: .string)

        TextCaptureService.accessibilityOverrideForTesting = true
        TextCaptureService.skipSimulatePasteForTesting = true
        TextCaptureService.forcePasteboardFallbackForTesting = true
        TextCaptureService.pasteboardRestoreDelayForTesting = 50_000_000
        TextCaptureService.simulatePasteDelayForTesting = 300_000_000
        defer {
            TextCaptureService.accessibilityOverrideForTesting = nil
            TextCaptureService.skipSimulatePasteForTesting = false
            TextCaptureService.forcePasteboardFallbackForTesting = false
            TextCaptureService.pasteboardRestoreDelayForTesting = nil
            TextCaptureService.simulatePasteDelayForTesting = nil
        }

        let task = Task { @MainActor in
            await TextCaptureService.shared.replaceSelection(with: "Replacement \(UUID().uuidString)")
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(TextCaptureService.shared.hasPendingRestoreTaskForTesting == false)
        #expect(TextCaptureService.shared.hasPendingRestore == true)
        _ = await task.value
        let deadline = Date().addingTimeInterval(2.0)
        while TextCaptureService.shared.hasPendingRestore && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        #expect(TextCaptureService.shared.hasPendingRestore == false)
    }

    @Test("Replace is refused for an ambiguous whole-line clipboard capture")
    @MainActor
    func ambiguousLineCopyIsNotReplaced() async {
        TextCaptureService.accessibilityOverrideForTesting = true
        defer { TextCaptureService.accessibilityOverrideForTesting = nil }
        let selection = CapturedSelection(text: "let x = 1\n", bounds: nil, mouseLocation: .zero, isAmbiguousLineCopy: true)
        #expect(await TextCaptureService.shared.replaceSelection(with: "let y = 2", verifying: selection) == false)
    }

    @Test("replaceSelection leaves an empty clipboard empty after the restore")
    @MainActor
    func replaceSelectionRestoresEmptyClipboard() async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        TextCaptureService.accessibilityOverrideForTesting = true
        TextCaptureService.skipSimulatePasteForTesting = true
        TextCaptureService.forcePasteboardFallbackForTesting = true
        TextCaptureService.pasteboardRestoreDelayForTesting = 50_000_000
        defer {
            TextCaptureService.accessibilityOverrideForTesting = nil
            TextCaptureService.skipSimulatePasteForTesting = false
            TextCaptureService.forcePasteboardFallbackForTesting = false
            TextCaptureService.pasteboardRestoreDelayForTesting = nil
        }

        let replaced = await TextCaptureService.shared.replaceSelection(with: "Replacement \(UUID().uuidString)")
        #expect(replaced)
        let deadline = Date().addingTimeInterval(2)
        while TextCaptureService.shared.hasPendingRestore && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        #expect(pasteboard.string(forType: .string) == nil)
    }

    @Test("Ambiguous rewrite needs a second press within the window")
    func ambiguousRewriteGate() {
        var gate = AmbiguousRewriteGate()
        let first = gate.confirm(text: "line\n", at: 100)
        let second = gate.confirm(text: "line\n", at: 102)
        let third = gate.confirm(text: "line\n", at: 103)
        let other = gate.confirm(text: "other\n", at: 104)
        let late = gate.confirm(text: "other\n", at: 110)
        #expect(!first)
        #expect(second)
        #expect(!third)
        #expect(!other)
        #expect(!late)
    }

    @Test("Confirming a line copy clears the ambiguity flag")
    func confirmingLineCopy() {
        let selection = CapturedSelection(text: "x\n", bounds: nil, mouseLocation: .zero, isAmbiguousLineCopy: true)
        #expect(selection.isAmbiguousLineCopy)
        #expect(!selection.confirmingLineCopy().isAmbiguousLineCopy)
    }

    @Test("clipboard capture returns the copied text and restores the user's clipboard")
    @MainActor
    func clipboardCaptureRestoresClipboard() async {
        let pasteboard = NSPasteboard.general
        let userText = "User clipboard \(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(userText, forType: .string)
        TextCaptureService.simulateCopyForTesting = {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("Selected words", forType: .string)
        }
        defer { TextCaptureService.simulateCopyForTesting = nil }

        let captured = await TextCaptureService.shared.getSelectionViaClipboard()
        #expect(captured == "Selected words")
        #expect(pasteboard.string(forType: .string) == userText)
    }

    @Test("clipboard capture returns nil when the copy produces nothing and keeps the user's clipboard")
    @MainActor
    func clipboardCaptureTimesOut() async {
        let pasteboard = NSPasteboard.general
        let userText = "User clipboard \(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(userText, forType: .string)
        TextCaptureService.simulateCopyForTesting = {}
        defer { TextCaptureService.simulateCopyForTesting = nil }

        let captured = await TextCaptureService.shared.getSelectionViaClipboard(timeout: 0.05)
        #expect(captured == nil)
        #expect(pasteboard.string(forType: .string) == userText)
    }

    @Test("clipboard capture treats a copy that leaves the clipboard unchanged as no selection")
    @MainActor
    func clipboardCaptureIgnoresUnchangedClipboard() async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("Old text", forType: .string)
        TextCaptureService.simulateCopyForTesting = { }
        defer { TextCaptureService.simulateCopyForTesting = nil }
        #expect(await TextCaptureService.shared.getSelectionViaClipboard(timeout: 0.05) == nil)
    }

    @Test("transient pasteboard items carry the clipboard-manager markers")
    func transientItemMarkers() {
        let item = TextCaptureService.makeTransientItem(text: "secret")
        #expect(item.string(forType: .string) == "secret")
        #expect(item.types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")))
        #expect(item.types.contains(NSPasteboard.PasteboardType("org.nspasteboard.transient")))
    }

    @Test("Line-copy heuristic applies only to editors known to copy the caret line")
    func editorsCopyingCaretLine() {
        #expect(TextCaptureService.copiesLineWhenSelectionEmpty(bundleID: "com.microsoft.VSCode"))
        #expect(TextCaptureService.copiesLineWhenSelectionEmpty(bundleID: "com.jetbrains.intellij"))
        #expect(!TextCaptureService.copiesLineWhenSelectionEmpty(bundleID: "com.tinyspeck.slackmacgap"))
        #expect(!TextCaptureService.copiesLineWhenSelectionEmpty(bundleID: nil))
    }

    @Test("StreamGate renders the first chunk, drops chunks within 50ms and nothing after finish")
    @MainActor
    func streamGateThrottle() {
        let gate = StreamGate()
        #expect(gate.shouldRender(at: 100.0))
        #expect(!gate.shouldRender(at: 100.02))
        #expect(gate.shouldRender(at: 100.06))
        #expect(gate.shouldRender(at: 50.0))
        gate.finished = true
        #expect(!gate.shouldRender(at: 500.0))
    }
}
