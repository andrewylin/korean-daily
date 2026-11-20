import Foundation

enum ClaudeClient {
    static let model = "claude-haiku-5-5"

    /// Asks Claude for one comprehensible-input sentence containing `word`.
    static func entry(for word: Word, apiKey: String) async throws -> Entry {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let prompt = """
        Write ONE natural Korean sentence for a learner who can read Hangul and knows about 100 words.
        Target word: \(word.ko) (\(word.en)).
        Rules:
        - Use the target word exactly once, as the only unfamiliar word.
        - Every other word must be extremely common beginner vocabulary.
        - Polite 해요체, at most 8 words, simple grammar.
        - The sentence must make the target word's meaning guessable from context.
        Reply with only JSON: {"ko": "<sentence>", "en": "<English translation>", "form": "<the target word exactly as it appears in the sentence>"}
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String,
              let open = text.firstIndex(of: "{"),
              let close = text.lastIndex(of: "}") else {
            throw URLError(.cannotParseResponse)
        }
        let entry = try JSONDecoder().decode(Entry.self, from: Data(text[open...close].utf8))
        guard entry.ko.contains(entry.form) else { throw URLError(.cannotParseResponse) }
        return entry
    }
}
