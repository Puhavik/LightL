import Testing
import Foundation
@testable import LightL

@Suite("Hardening")
struct HardeningTests {
    @Test("rewrite rejects input above the length limit")
    func inputTooLong() async {
        let text = String(repeating: "a", count: GeminiService.maxInputCharacters + 1)
        await #expect(throws: GeminiError.self) {
            _ = try await GeminiService.shared.rewrite(text: text, mode: .proofread, apiKey: "k")
        }
    }

    @Test("testApiKey rejects model IDs with path traversal")
    func invalidModel() async {
        for bad in ["../../v1beta/files", "x/y", "a b", "..", ""] {
            await #expect(throws: GeminiError.self) {
                try await GeminiService.shared.testApiKey(apiKey: "k", model: bad)
            }
        }
    }

    @Test("isTruncated detects MAX_TOKENS finish reason")
    func truncation() {
        let cut = Data(#"{"candidates":[{"content":{"parts":[{"text":"x"}]},"finishReason":"MAX_TOKENS"}]}"#.utf8)
        let ok = Data(#"{"candidates":[{"content":{"parts":[{"text":"x"}]},"finishReason":"STOP"}]}"#.utf8)
        #expect(GeminiService.isTruncated(cut))
        #expect(!GeminiService.isTruncated(ok))
    }
}

@Suite("Double-tap secret guard")
struct DoubleTapGuardTests {
    @Test("skips password managers and concealed clipboard, allows normal apps")
    func guardRules() {
        let plain = ["public.utf8-plain-text"]
        #expect(HotKeyManager.shouldSkipDoubleTap(pasteboardTypes: plain, frontmostBundleID: "com.apple.Passwords"))
        #expect(HotKeyManager.shouldSkipDoubleTap(pasteboardTypes: plain, frontmostBundleID: "com.bitwarden.desktop"))
        #expect(HotKeyManager.shouldSkipDoubleTap(pasteboardTypes: plain + ["org.nspasteboard.ConcealedType"], frontmostBundleID: "com.apple.Safari"))
        #expect(!HotKeyManager.shouldSkipDoubleTap(pasteboardTypes: plain, frontmostBundleID: "com.apple.Safari"))
        #expect(!HotKeyManager.shouldSkipDoubleTap(pasteboardTypes: plain, frontmostBundleID: nil))
    }
}

@Suite("Echoed delimiter tags")
struct StripTagTests {
    @Test("removes echoed open/close tags and partial tags from streamed text")
    func strip() {
        let tag = "input-3af13b590560"
        #expect(GeminiService.stripInputTag("<\(tag)>\nHello\n</\(tag)>", tag: tag) == "Hello")
        #expect(GeminiService.stripInputTag("<\(tag)>\nHel", tag: tag) == "Hel")
        #expect(GeminiService.stripInputTag("Hello\n</input-3af", tag: tag) == "Hello")
        #expect(GeminiService.stripInputTag("a < b and c", tag: tag) == "a < b and c")
        #expect(GeminiService.stripInputTag("Hello", tag: tag) == "Hello")
        #expect(GeminiService.stripInputTag("if a <", tag: tag, isFinal: true) == "if a <")
    }
}
