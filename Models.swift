import Foundation
import Security

enum Keys {
    static let startHour = "startHour"        // Int, default 8
    static let endHour = "endHour"            // Int, default 21
    static let intervalMinutes = "intervalMinutes" // Int, default 120
    static let useAPI = "useAPI"              // Bool, default false
}

/// One vocabulary item. `s` and `t` are optional: items without a bundled
/// sentence get one from the Claude API when the API is enabled.
struct Word: Codable, Identifiable, Hashable {
    let ko: String      // dictionary form
    let f: String       // form as it appears in the sentence (for highlighting)
    let en: String      // gloss
    var s: String?      // bundled Korean sentence
    var t: String?      // bundled English translation
    var id: String { ko }
}

/// A sentence ready to display or send.
struct Entry: Codable, Hashable {
    let ko: String
    let en: String
    let form: String
}

final class WordStore: ObservableObject {
    @Published private(set) var words: [Word] = []

    init() {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Word].self, from: data) else { return }
        words = list
    }

    func bundledEntry(_ w: Word) -> Entry? {
        guard let s = w.s, let t = w.t else { return nil }
        return Entry(ko: s, en: t, form: w.f)
    }

    /// Random order, cycling through every word before repeating any.
    func pickWords(count: Int) -> [Word] {
        guard !words.isEmpty else { return [] }
        var out: [Word] = []
        while out.count < count { out += words.shuffled() }
        return Array(out.prefix(count))
    }

    func randomWord() -> Word? { words.randomElement() }
}

enum Keychain {
    private static let service = "KoreanDaily"
    private static func base() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "anthropic"]
    }
    static func set(_ value: String) {
        SecItemDelete(base() as CFDictionary)
        guard !value.isEmpty else { return }
        var q = base()
        q[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(q as CFDictionary, nil)
    }
    static func get() -> String? {
        var q = base()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
