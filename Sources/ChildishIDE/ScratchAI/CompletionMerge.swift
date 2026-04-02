import Foundation

/// Turns a tapped chip into a sane editor patch (prefix-finish vs append vs spaced word).
enum CompletionMerge {
    static func apply(draft: String, snippet: String) -> String {
        if snippet.isEmpty { return draft }

        var runStart = draft.endIndex
        var j = draft.endIndex
        while j > draft.startIndex {
            let i = draft.index(before: j)
            let c = draft[i]
            if c.isLetter || c.isNumber || c == "_" || c == "$" {
                runStart = i
                j = i
                continue
            }
            break
        }

        if runStart < draft.endIndex {
            let frag = String(draft[runStart...])
            if !frag.isEmpty, snippet.hasPrefix(frag) {
                return String(draft[..<runStart]) + snippet
            }
        }

        guard let last = draft.last else {
            return draft + snippet
        }

        if !last.isWhitespace {
            if let f = snippet.first {
                if f.isLetter || f == "_" || f == "$" {
                    return draft + " " + snippet
                }
                if f == "{" {
                    return draft + " " + snippet
                }
            }
        }

        return draft + snippet
    }
}
