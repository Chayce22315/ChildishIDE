import Foundation

/// Lexical completion from n-grams in local text only (no network).
/// Feels closer to “real” IDE completion than single-character guesses.
final class LocalPhraseIndex {
    private var afterWord: [String: [String: Int]] = [:]
    private var afterBigram: [String: [String: Int]] = [:]
    private var lineStarters: [String: Int] = [:]
    private var vocabulary = Set<String>()

    func ingest(lines: [String]) {
        for line in lines {
            let tokens = Self.tokenize(line)
            guard !tokens.isEmpty else { continue }
            for t in tokens { vocabulary.insert(t) }
            lineStarters[tokens[0], default: 0] += 1
            for i in 0 ..< tokens.count - 1 {
                let w = tokens[i]
                let nxt = tokens[i + 1]
                afterWord[w, default: [:]][nxt, default: 0] += 1
                if i > 0 {
                    let prev = tokens[i - 1]
                    let key = prev + "|" + w
                    afterBigram[key, default: [:]][nxt, default: 0] += 1
                }
            }
        }
    }

    func ingest(paragraph: String) {
        ingest(lines: paragraph.split(whereSeparator: \.isNewline).map(String.init))
    }

    /// Returns multi-token insertion strings (include trailing space when it helps).
    func completions(following text: String, limit: Int) -> [String] {
        let tokens = Self.tokenize(text)
        var scores: [String: Int] = [:]

        func merge(_ m: [String: Int]) {
            for (k, v) in m {
                scores[k, default: 0] += v
            }
        }

        if tokens.isEmpty {
            merge(lineStarters)
            return Self.rank(scores, limit: limit)
        }

        let last = tokens[tokens.count - 1]
        merge(afterWord[last] ?? [:])

        if tokens.count >= 2 {
            let prev = tokens[tokens.count - 2]
            let key = prev + "|" + last
            merge(afterBigram[key] ?? [:])
        }

        if last.count >= 2 {
            for w in vocabulary where w != last && w.hasPrefix(last) {
                scores[w, default: 0] += max(1, w.count - last.count)
            }
        }

        if scores.isEmpty {
            merge(lineStarters)
        }

        return Self.rank(scores, limit: limit)
    }

    private static func rank(_ scores: [String: Int], limit: Int) -> [String] {
        scores.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        .prefix(limit)
        .map(\.key)
    }

    /// Lowercased “words” for matching; keeps Swift-ish tokens useful.
    private static func tokenize(_ line: String) -> [String] {
        var out: [String] = []
        var current = ""
        func flush() {
            let t = current.lowercased()
            if !t.isEmpty { out.append(t) }
            current = ""
        }
        for ch in line {
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "$" {
                current.append(ch)
            } else {
                flush()
                if "{}[]();:.,<>+-*/%=!&|^~?".contains(ch) {
                    out.append(String(ch))
                }
            }
        }
        flush()
        return out
    }
}
