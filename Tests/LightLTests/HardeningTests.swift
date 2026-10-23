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
