import Foundation

public enum GeminiError: LocalizedError {
    case missingApiKey
    case invalidURL
    case badServerResponse(statusCode: Int, message: String)
    case emptyResponse
    case decodingError(String)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return L10n.tr(
                ru: "Не указан API ключ Gemini. Откройте настройки и введите ключ.",
                en: "Gemini API key is missing. Please open Settings and enter your key."
            )
        case .invalidURL:
            return L10n.tr(
                ru: "Неверный URL запроса к API.",
                en: "Invalid API request URL."
            )
        case .badServerResponse(let code, let msg):
            return L10n.tr(
                ru: "Ошибка сервера Gemini (\(code)): \(msg)",
                en: "Gemini server error (\(code)): \(msg)"
            )
        case .emptyResponse:
            return L10n.tr(
                ru: "Сервер Gemini вернул пустой ответ.",
                en: "Gemini server returned an empty response."
            )
        case .decodingError(let msg):
            return L10n.tr(
                ru: "Ошибка обработки ответа: \(msg)",
                en: "Response decoding error: \(msg)"
            )
        case .networkError(let err):
            return L10n.tr(
                ru: "Ошибка сети: \(err.localizedDescription)",
                en: "Network error: \(err.localizedDescription)"
            )
        }
    }
}

public actor GeminiService {
    public static let shared = GeminiService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25.0
        config.timeoutIntervalForResource = 35.0
        config.waitsForConnectivity = false
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
    }

    /// Pre-warms the HTTP/2 & TLS 1.3 connection to Google Gemini API to eliminate initial handshake latency
    public func prewarm() {
        Task {
            guard let url = URL(string: "https://generativelanguage.googleapis.com") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 4.0
            _ = try? await session.data(for: request)
        }
    }

    public func translate(
        text: String,
        targetLanguage: LanguageModel,
        apiKey: String,
        model: String = "gemini-3.5-flash-lite",
        onChunk: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.missingApiKey
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }

        // Highly compressed system prompt for sub-200ms TTFT
        let systemPrompt = "Translate to \(targetLanguage.name) (\(targetLanguage.nativeName)). Output ONLY translation. Keep formatting. Never add quotes or conversational text."

        return try await generate(
            prompt: trimmedText,
            systemInstruction: systemPrompt,
            apiKey: apiKey,
            model: model,
            temperature: 0.1,
            onChunk: onChunk
        )
    }

    public func rewrite(
        text: String,
        mode: RewriteMode,
        apiKey: String,
        model: String = "gemini-3.5-flash-lite"
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.missingApiKey
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }

        let systemPrompt: String
        switch mode {
        case .proofread:
            systemPrompt = "Correct spelling, grammar, punctuation in same language. Output ONLY corrected text. Keep formatting. Never add quotes or commentary."
        case .improveStyle:
            systemPrompt = "Refine and polish text in same language. Output ONLY polished text. Keep core meaning and formatting. Never add quotes or greetings."
        }

        return try await generate(
            prompt: trimmedText,
            systemInstruction: systemPrompt,
            apiKey: apiKey,
            model: model,
            temperature: mode == .proofread ? 0.1 : 0.4,
            onChunk: nil
        )
    }

    public func testApiKey(apiKey: String, model: String = "gemini-3.5-flash-lite") async throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.missingApiKey
        }

        // Lightweight ping with zero thinking budget for sub-second confirmation
        _ = try await generate(
            prompt: "Ping",
            systemInstruction: "Respond with OK",
            apiKey: apiKey,
            model: model,
            temperature: 0.0,
            onChunk: nil
        )
    }

    private func generate(
        prompt: String,
        systemInstruction: String,
        apiKey: String,
        model: String,
        temperature: Double,
        onChunk: (@Sendable (String) -> Void)?
    ) async throws -> String {
        var cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanModel.hasPrefix("models/") {
            cleanModel = String(cleanModel.dropFirst(7))
        }
        let encodedModel = cleanModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanModel

        let action = onChunk != nil ? "streamGenerateContent?alt=sse" : "generateContent"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):\(action)"

        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        // Bounded maxOutputTokens prevents runaway generation and limits token cost
        let maxTokens = max(128, min(4096, (prompt.count * 3) / 2 + 100))
        var generationConfig: [String: Any] = [
            "temperature": temperature,
            "maxOutputTokens": maxTokens
        ]

        // Eliminate thinking latency for reasoning models
        let isLite = cleanModel.contains("lite")
        let supportsThinking = !isLite && (cleanModel.contains("3.8") || cleanModel.contains("2.5") || cleanModel.contains("2.0") || cleanModel.contains("thinking"))
        if supportsThinking {
            generationConfig["thinkingConfig"] = [
                "thinkingBudget": 0
            ]
        }

        if let onChunk = onChunk {
            return try await executeStreamGenerate(
                url: url,
                prompt: prompt,
                systemInstruction: systemInstruction,
                apiKey: apiKey,
                generationConfig: generationConfig,
                onChunk: onChunk
            )
        } else {
            return try await executeGenerate(
                url: url,
                prompt: prompt,
                systemInstruction: systemInstruction,
                apiKey: apiKey,
                generationConfig: generationConfig,
                canRetryWithoutThinking: generationConfig["thinkingConfig"] != nil
            )
        }
    }

    private func executeStreamGenerate(
        url: URL,
        prompt: String,
        systemInstruction: String,
        apiKey: String,
        generationConfig: [String: Any],
        onChunk: @Sendable (String) -> Void
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-goog-api-key")

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "generationConfig": generationConfig
        ]

        let requestData: Data
        do {
            requestData = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw GeminiError.decodingError("Ошибка сериализации запроса: \(error.localizedDescription)")
        }
        request.httpBody = requestData

        let (asyncBytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (asyncBytes, response) = try await session.bytes(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.emptyResponse
        }

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in asyncBytes.lines {
                errorBody += line
                if errorBody.count > 500 { break }
            }
            var errorMessage = "HTTP \(httpResponse.statusCode)"
            if let data = errorBody.data(using: .utf8),
               let errObj = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               let msg = errObj.error?.message {
                errorMessage = msg
            }
            throw GeminiError.badServerResponse(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        var accumulatedText = ""
        for try await line in asyncBytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data: ") else { continue }
            let jsonString = String(trimmed.dropFirst(6))
            guard let data = jsonString.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(GeminiResponseDTO.self, from: data) else {
                continue
            }

            if let blockReason = chunk.promptFeedback?.blockReason {
                throw GeminiError.decodingError("Запрос заблокирован Gemini (причина: \(blockReason)).")
            }

            if let candidate = chunk.candidates?.first {
                if let finish = candidate.finishReason {
                    if finish == "SAFETY" {
                        throw GeminiError.decodingError("Ответ заблокирован фильтрами безопасности Gemini.")
                    } else if finish == "RECITATION" {
                        throw GeminiError.decodingError("Ответ заблокирован из-за совпадения с источником (RECITATION).")
                    }
                }

                if let parts = candidate.content?.parts {
                    for part in parts {
                        if part.thought == true { continue }
                        if let piece = part.text, !piece.isEmpty {
                            accumulatedText += piece
                            onChunk(accumulatedText)
                        }
                    }
                }
            }
        }

        let trimmedResult = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResult.isEmpty else {
            throw GeminiError.emptyResponse
        }
        return trimmedResult
    }

    private func executeGenerate(
        url: URL,
        prompt: String,
        systemInstruction: String,
        apiKey: String,
        generationConfig: [String: Any],
        canRetryWithoutThinking: Bool
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-goog-api-key")

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "generationConfig": generationConfig
        ]

        let requestData: Data
        do {
            requestData = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw GeminiError.decodingError("Ошибка сериализации запроса: \(error.localizedDescription)")
        }
        request.httpBody = requestData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.emptyResponse
        }

        // If 400 Bad Request occurred and thinkingConfig was passed, retry without thinkingConfig
        if httpResponse.statusCode == 400 && canRetryWithoutThinking {
            var fallbackConfig = generationConfig
            fallbackConfig.removeValue(forKey: "thinkingConfig")
            return try await executeGenerate(
                url: url,
                prompt: prompt,
                systemInstruction: systemInstruction,
                apiKey: apiKey,
                generationConfig: fallbackConfig,
                canRetryWithoutThinking: false
            )
        }

        if httpResponse.statusCode != 200 {
            var errorMessage = "HTTP \(httpResponse.statusCode)"
            if let errorObj = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               let msg = errorObj.error?.message {
                errorMessage = msg
            }
            throw GeminiError.badServerResponse(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        return try Self.parseResponseData(data)
    }

    private struct GeminiErrorResponse: Decodable {
        struct ErrorDetail: Decodable {
            let message: String?
            let code: Int?
        }
        let error: ErrorDetail?
    }

    private struct GeminiResponseDTO: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                    let thought: Bool?
                }
                let parts: [Part]?
            }
            let content: Content?
            let finishReason: String?
        }
        struct PromptFeedback: Decodable {
            let blockReason: String?
        }
        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?
    }

    public static func parseResponseData(_ data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(GeminiResponseDTO.self, from: data) else {
            throw GeminiError.decodingError("Не удалось распарсить JSON ответ сервера.")
        }

        if let blockReason = response.promptFeedback?.blockReason {
            throw GeminiError.decodingError("Запрос заблокирован Gemini (причина: \(blockReason)).")
        }

        guard let firstCandidate = response.candidates?.first else {
            throw GeminiError.emptyResponse
        }

        if let finishReason = firstCandidate.finishReason {
            switch finishReason {
            case "SAFETY":
                throw GeminiError.decodingError("Ответ заблокирован фильтрами безопасности Gemini.")
            case "RECITATION":
                throw GeminiError.decodingError("Ответ заблокирован из-за совпадения с источником (RECITATION).")
            default:
                break
            }
        }

        guard let parts = firstCandidate.content?.parts else {
            if let reason = firstCandidate.finishReason {
                throw GeminiError.decodingError("Пустой ответ от Gemini (причина: \(reason)).")
            }
            throw GeminiError.emptyResponse
        }

        // Safely extract text, ignoring internal thought parts
        var resultText = ""
        for part in parts {
            if part.thought == true {
                continue
            }
            if let text = part.text {
                resultText += text
            }
        }

        let trimmed = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if let reason = firstCandidate.finishReason {
                throw GeminiError.decodingError("Пустой ответ от Gemini (причина: \(reason)).")
            }
            throw GeminiError.emptyResponse
        }

        return trimmed
    }
}
