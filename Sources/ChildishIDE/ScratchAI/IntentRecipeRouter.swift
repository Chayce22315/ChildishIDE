import Foundation

/// Picks a full-code recipe from a short natural-language wish (offline keyword match).
enum IntentRecipeRouter {
    static func bestMatch(for wish: String) -> CodeRecipe? {
        let tokens = tokenize(wish)
        let corpus = CodeRecipes.all

        if tokens.isEmpty {
            return corpus.first { $0.id == "swiftui_screen" } ?? corpus.first
        }

        var best: (recipe: CodeRecipe, score: Int)?
        for r in corpus {
            var score = 0
            for kw in r.keywords {
                if tokens.contains(kw) {
                    score += 5
                }
                for t in tokens where t.count >= 3 {
                    if kw.hasPrefix(t) || t.hasPrefix(kw) {
                        score += 2
                    }
                }
            }
            if score > best?.score ?? -1 {
                best = (r, score)
            }
        }

        if let b = best, b.score > 0 {
            return b.recipe
        }

        // Fuzzy fallback: any keyword substring in wish
        let flat = wish.lowercased()
        for r in corpus {
            for kw in r.keywords where flat.contains(kw) {
                return r
            }
        }

        return corpus.first { $0.id == "swiftui_screen" }
    }

    private static func tokenize(_ s: String) -> [String] {
        let lowered = s.lowercased()
        var tokens: [String] = []
        var cur = ""
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                cur.append(ch)
            } else {
                if cur.count >= 2 {
                    tokens.append(cur)
                }
                cur = ""
            }
        }
        if cur.count >= 2 {
            tokens.append(cur)
        }
        return tokens
    }
}
