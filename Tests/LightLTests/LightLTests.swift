import Testing
import SwiftUI
import Foundation
import Carbon
import AppKit
@testable import LightL

@Suite("LightL Unit Tests", .serialized)
struct LightLTests {
}

final class TruncatedStreamURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestCount = 0
    nonisolated(unsafe) static var queuedResponses: [(status: Int, body: String)] = []
    nonisolated(unsafe) static var requestBodies: [String] = []
    static let truncatedBody = "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"partial\"}]}}]}\n\n"
        + "data: {\"candidates\": [{\"content\": {\"parts\": []}, \"finishReason\": \"MAX_TOKENS\"}]}\n\n"
    nonisolated(unsafe) static var body = truncatedBody

    static func reset() {
        requestCount = 0
        queuedResponses = []
        requestBodies = []
        body = truncatedBody
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        var bodyData = Data()
        if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                bodyData.append(buffer, count: n)
            }
            stream.close()
        } else if let data = request.httpBody {
            bodyData = data
        }
        Self.requestBodies.append(String(decoding: bodyData, as: UTF8.self))
        let next = Self.queuedResponses.isEmpty ? (status: 200, body: Self.body) : Self.queuedResponses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: next.status, httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(next.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
